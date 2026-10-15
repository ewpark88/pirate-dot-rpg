# 작업 분해: 현상금 사냥 (기획 `docs/specs/platform-content-bounty.md`)

- 2026-10-15, S5 작성 · S1 배정용. 레인: **계약 = S1** · **battle = S1(battle 레인, 위임하면 S2)** · **economy = S2** · **ui = S4** · **render/art = S3** · platform = S5.
- 원칙: 계약(명령·이벤트·세이브) 먼저 머지 → 코어·UI가 **동시에** 시작(UI는 가짜 상태·운영자 명령으로). 단위마다 테스트 먼저, check --full 통과, 작은 커밋.
- 표기: `[ ]` 할 일 · **완료 기준**은 기획서 8절 수용 기준 번호(AC n).

## 0. 순서 한눈에
```
C1 계약 ──┬─ E1 표 ─ E2 티켓 ─ E3 보상·소탕 ─ E4 광고 ─ E5 sim
          ├─ B1 전투 모드 ─ B2 종료·복귀 ─ B3 시나리오
          ├─ U1 항해 탭 카드 ─ U2 시트 ─ U3 전투 띠·결과 ─ U4 점·골든
          └─ R1 수배 포스터 컷인(S3)            → I1 통합·실기기(S1)
```

## C. 계약 — S1 (먼저, 반나절)
- [ ] **C1** `packages/game_core` 계약 추가 + 리뷰
  - 명령: `StartBounty(bossId, tier)` · `SweepBounty(bossId, count)` · `RetreatBounty()`
  - 이벤트: `BountyStarted(bossId, tier, timeLimitTicks)` · `BountyCleared(bossId, tier, reward)` · `BountyFailed(bossId, tier, damageRatio)` · `BountySwept(bossId, tier, count, reward)` · `BountyTicketsRefilled(count)`
  - `AdPlacement.bountyTicket`
  - `BattleView`: `mode`(`stage`|`bounty`) · `bountyTicksLeft`
  - 세이브 v6: `bounty: {tickets, refilledOn, cleared{}, progress{}}` + v5→v6 마이그레이션(티켓 3) + `fixtures/saves/v6.json`
  - 운영자: `OpSetBountyTickets(n)` · `OpSetWeekday(1..7)`(요일 고정, 테스트·QA용)
  - **완료**: JSON 왕복 테스트, 마이그레이션 테스트, check --full

## E. 경제 — S2
- [ ] **E1** 표 `packages/game_data/tables/bounty.json` + `BountyTable` 모델(`economy_tables.dart`) + 검증(요일 7개, 보스 id가 regions.bosses에 있음, maxTier ≥ 1). `ads.json`에 `bountyTicket`(dailyLimit 1)
  - **완료**: game_data 테스트, gen_tables
- [ ] **E2** 티켓 충전 `economy/bounty.dart` — 현지 날짜가 바뀐 첫 틱에 `일수 × ticketsPerDay`(상한 `ticketCap`), `BountyTicketsRefilled`. 날짜 비교는 `daily.dart`와 같은 함수 재사용
  - **완료**: AC1 (3일 전·티켓 2 → 9, 이벤트 7)
- [ ] **E3** 도전 가능 판정(요일·일요일 전체·열린 단계·티켓) / 보상 계산(`floor(base + perTier×(t−1))`, 카드는 보유 선원 결정론 추첨, `mapPieces`는 환생 조각에 가산, `gifts`는 호감 기획 전까지 젬 10) / `SweepBounty`
  - **완료**: AC2 · AC3 · AC6(같은 시드 같은 카드)
- [ ] **E4** 광고 티켓: `GrantAdReward(bountyTicket)` → 티켓 +1(상한 넘어도 +1, 하루 1회)
  - **완료**: AC8
- [ ] **E5** sim: `game_cli sim`에 현상금 하루 3장 소탕 가정 추가 → **하루 젬 ≤ 140**(개요), 단계 상한 30에서 젬 요일 보상 확인 → `perTier` 조정
  - **완료**: sim 보고 1줄(PROGRESS)

## B. 전투 — battle 레인(S1, 위임 시 S2)
- [ ] **B1** 현상금 모드 `battle/bounty_mode.dart`: `StartBounty` 처리 시 본 전투 상태 보관 → 필드 비우고 보스 1 스폰(HP = 스테이지 `t×stagePerTier` 해역 보스 × `hpMultiplier`, 기믹 그대로), 무리 없음, 타이머 `waves.boss.timeLimitSec`. 난수는 `rngSeed`에서 갈라 쓰기
  - **완료**: 단위 테스트(보스 HP·타이머), 결정론
- [ ] **B2** 종료·복귀: 처치 → `BountyCleared`(경제가 보상) / 시간 초과·`RetreatBounty`·앱 pause → `BountyFailed`(티켓 반환 — 경제) → 본 전투를 **같은 스테이지 같은 파 처음부터** 재개(환생 복귀 규칙 재사용). 현상금 중엔 스테이지 진행·오프라인 계산 안 함
  - **완료**: AC4 · AC5 · AC7
- [ ] **B3** 시나리오 `scenarios/bounty_clear.yaml` · `scenarios/bounty_fail.yaml`(운영자 `OpSetWeekday`·`OpSetBountyTickets`로 고정)
  - **완료**: 시나리오 리플레이 통과

## U. UI — S4 (C1 머지 직후 시작 가능, 가짜 상태로)
- [ ] **U1** 항해 탭 카드 `ui/tabs/bounty_card.dart`(보물지도 카드 위): 오늘 보스 초상·이름·요일 보상 아이콘, 티켓 `n/9`, [도전] [소탕 ×N], 티켓 0이면 [광고로 1장](오늘 안 봤고 광고 준비됐을 때만)
  - **완료**: 위젯 테스트(버튼 표시 조건 4가지), 문구 키 ko/en
- [ ] **U2** 현상금 시트 `ui/meta/bounty_sheet.dart`: 보스 7칸(오늘 강조, 일요일 전부), 단계 − t +(깬 최고 단계까지 + 1), 다음 단계 진행 막대, [도전]·[소탕]
  - 태블릿(800×1280): 7칸 한 줄, 폰은 4+3
  - **완료**: 골든 ko/en · 360/384/411dp · 태블릿 1장, 넘침 0
- [ ] **U3** 현상금 전투 중 화면: 전장 위 '현상금' 띠 + 남은 시간(캔버스 HUD 보스 타이머 재사용 여부는 S3와 합의), 선원 줄 오른쪽 [후퇴](궁극기 옆), 끝나면 결과 작은 창(성공: 보상 숫자 올라가기 / 실패: '티켓은 돌려받았어요 · 피해 62%') — 팝업 1개 규칙: 결과 창은 사용자가 시작한 행동의 결과라 예외로 허용(4.9 '접속 때 팝업'과 다름)
  - **완료**: 위젯 테스트(후퇴 → `RetreatBounty`), 골든 2장
- [ ] **U4** 빨간 점: 항해 탭 아이콘 — 티켓이 상한(9)일 때만. Analytics `bounty_start/clear/fail/sweep`(analyticsPortProvider)
  - **완료**: 점 조건 테스트(8장 → 없음, 9장 → 있음)

## R. 렌더·아트 — S3 (작음)
- [ ] **R1** 수배 포스터 컷인: 양피지 틀 그림 1장(art) + 기존 해역 보스 컷인(`fx_map.cutIn`)에 틀·현상금 숫자 얹기, 0.8초. `BountyStarted`에 반응. 번쩍임 설정 따름
  - **완료**: 렌더 골든 1장, 부하 장면 성능 기준 유지

## I. 통합 — S1 (+ S5 실기기)
- [ ] **I1** 머지 순서: C1 → (E1·B1·U1 병렬) → E2·E3·B2·U2 → E4·B3·U3·R1 → E5·U4
- [ ] **I2** 실기기(S5, 사용자 쉬는 시간·우리 앱이 앞일 때만): 운영자 빌드로 요일 고정 → 도전·성공·실패·후퇴·소탕·광고 티켓 → `device_shots.py` 캡처 + release_smoke
- [ ] **I3** 스토어 문구 한 줄(platform), DEVICE_TEST에 현상금 항목(S1)

## 규모 감
| 단위 | 레인 | 크기 |
| --- | --- | --- |
| C1 | S1 | 0.5세션 |
| E1~E5 | S2 | 1.5세션 |
| B1~B3 | S1(또는 S2) | 2세션 — 가장 큼(전투 모드 전환·복귀) |
| U1~U4 | S4 | 1.5세션 |
| R1 | S3 | 0.3세션 |
| I1~I3 | S1·S5 | 0.5세션 |

## 위험·열린 점
- 현상금 중 앱이 죽으면(프로세스 종료) 세이브에는 현상금 상태가 없음 → 다음 실행은 본 전투, **티켓은 이미 차감**. B2에서 '시작 시 차감 → 실패·종료 시 반환'을 세이브에 반영하려면 `bounty.active`(선택 키) 필요 — C1에서 결정.
- 단계 30 이후 보상 정체 → 2차 '무한 단계'.

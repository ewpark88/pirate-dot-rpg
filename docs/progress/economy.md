# economy 레인 진척 (S2)

## 현재 위치
| 항목 | 내용 |
| --- | --- |
| 마일스톤 | M1 EconomySystem |
| 스펙·계획 | `docs/specs/economy-m1.md` · 완료 `docs/plans/done/economy-m1.md` · 진행 `docs/plans/active/economy-balance-m1.md` |
| 바로 다음 할 일 | 스테이지 10·40 진행 속도 — S1(전투 HP·골드 곡선)과 함께 조정 |
| 막힌 것 | 스테이지 40은 배 비용 곡선만으로 못 맞춤 — 전투 테이블과 함께(S1 협의 중) |

## 세션 로그 (최신이 위)

### 2026-10-14 · S2 · 사용자 결정 반영 + 복귀 미리보기 + 첫 10연 무료
- 사용자 결정(S1 경유): 광고 30젬, 옥토 시작 카드 14장, 오프라인 효율 계수, 무료 10연(세이브 v2 summonsTotal), 스테이지 40은 플레이 시간 기준.
- 한 일: `meta.offline` efficiency 0.01·minWaveSec 30·minSec 60, `offlinePreview`(UI 복귀 팝업, ClaimOffline과 같은 계산),
  `summonCostFor`·`isFreeFirstTen`(첫 보스 뒤 첫 10연 무료 + 영웅 확정), 모든 소환이 summonsTotal 증가. economy 테스트 67개.
- sim 20명×3시간: 7개 중 5개 OK(첫 보스 실패 1.3분, 첫 소환 2.8분, 벽 1.5분, 오프라인 5회, 광고 1회). 벗어남: 스테이지 10 5.6분, 스테이지 40 0.34시간.
- 탐색: 배 비용 곡선 11가지 조합으로는 스테이지 10·40·벽을 동시에 못 맞춤 → 계획 파일 표. 전투 곡선과 함께 조정해야 함.
- 실수 기록: sweep 마지막 시험값(efficiency 0.003)이 한 번 커밋됐다가 다음 커밋에서 0.01로 바로잡음.
  임시 측정 테스트가 run(total)을 누적 시간으로 착각해 무한 루프 → 중단.
- 남은 문제: 무료 10연이 옥토를 희귀 이상으로 점프시키면 ‘첫 승급’ 이벤트가 116분으로 늦어짐 — 점프도 첫 승급으로 칠지 지표 정의 필요.

### 2026-10-14 · S2 · 밸런스 기준선 + sim 진단·테스트
- 한 일: main(76bad8f LANES에 game_cli/test/sim, d26fcae 전투 HP 조정) 머지. sim에 ‘오프라인 추정 ÷ 실제 초당 골드’ 진단 추가,
  `packages/game_cli/test/sim/sim_test.dart` 6개. 기준선 20명×3시간·하루 일정 72시간을 계획 파일에 기록.
- 발견: 오프라인 추정이 실제의 4.87배. 추정을 맞춰도 8시간 = 강화 약 45회라 설계서 4.7 공식과 7.2 목표(3~8회)가 충돌.
  첫 승급 75분(목표 30~40분) — ‘옥토 보스 카드 10장 → 첫 승급’이 수치상 14장 필요. 무료 10연은 상태 필드가 없어 계약 요청.
- 경제 테이블은 아직 바꾸지 않았다(위 결정 대기).

### 2026-10-14 · S2 · game_cli sim (M1 단계 완료)
- 한 일: `game_cli/lib/src/sim/`(sim_player·sim_report) + `sim` 명령. 실제 CoreEngine을 돌린다(2시간분 약 2초).
  정책: 가장 싼 강화, 젬이 모이면 소환(10연 우선), 합치기·승급, 보스 실패 시 60초 파밍 후 재도전. 일정 `--schedule continuous|daily`.
  목표 범위는 `meta.json sim.targets`. check 밸런스 스모크가 ‘건너뜀’에서 실제 실행으로(수용 기준 13).
- sim 리포트 (seed 1, 계속 접속 2시간):

  | 지표 | 값 | 목표 | 판정 |
  | --- | --- | --- | --- |
  | 첫 보스 실패 | 1.52분 | 1~3 | OK |
  | 첫 소환 가능 | 15.8분 | 0~5 | 벗어남 |
  | 스테이지 10 | 17.2분 | 6~12 | 벗어남 |
  | 스테이지 40 | 0.53시간 | 1.5~3 | 벗어남 (하루 40분 일정이면 8.54시간) |
  | 가장 긴 벽 | 12.06분 | ≤20 | OK |
  | 오프라인 8시간 = 강화 | 128회 | 3~8 | 벗어남 |
  | 젬 광고 1회 = 소환 | 0.67회 | 1 | 벗어남 (altGems 20 / 소환 30젬) |

  참고: 최고 스테이지 145, 한 파 소요 처음 10분 33.1초 / 전체 14.8초(S1 요청 지표), 첫 승급 36분(목표 30~40분 OK).
- 요약: 초반이 느리고(파 33초) 중반부터 너무 빠르다(2시간에 145). 오프라인 추정이 너무 후하다.
- 남은 문제: sim 테스트 경로(`packages/game_cli/test/sim/`)가 레인 소유가 아님 → S1에 요청. 지금은 check 스모크가 검증
- 실수 기록: WIP 커밋에 `--no-verify`를 붙였다(저장소에 git 훅이 없어 건너뛴 검사는 없음). 다시 쓰지 않는다

### 2026-10-14 · S2 · 운영자 명령
- 한 일: `economy/operator.dart` — OpSetCrew·OpGrant·OpSetShip·OpAdvanceClock(savedAt을 과거로). economy 테스트 58개
- 남은 문제: `OpRebirthNow`·`OpReset`은 환생 구현(M1 밖, 계획 7번 이후)과 함께

### 2026-10-14 · S2 · 보스 카드·오프라인
- 한 일: `cards.dart`에 rollRarity·grantBossCards(state, ctx, fleet), `offline.dart`(fleetDps·goldPerSecEstimate·offlineFleet·ClaimOffline).
  수용 기준 12 + 보스 카드 장수·옥토 몰아주기·환생 후 해제. economy 테스트 53개
- 정한 것(스펙에 반영): 오프라인 카드 등급 = 보스 드롭 확률, 대상 = 지금 슬롯 autoFleet, 받으면 savedAt = now
- 남은 문제: DPS 추정은 범위 이득을 뺀 단일 대상 기준 — sim에서 실제 엔진과 비교해 보정 필요

### 2026-10-14 · S2 · 합치기·승급
- 한 일: `economy/merge.dart` — mergeCrew·MergeAllCards(승급 문에서 멈춤, 남는 경험치·장수 보존)·PromoteCrew(카드·골드·증표 차감, `CrewPromoted`). 수용 기준 9~10, economy 테스트 43개
- 남은 문제: 합치기로 레벨이 오를 때 낼 계약 이벤트가 없다(UI는 상태 변화로 표시). 필요하면 `CrewLeveled` 요청
- 다음 할 일: 6단계 grantBossCards·오프라인

### 2026-10-14 · S2 · 소환·천장·카드 받기 + UI용 판정 함수
- 한 일: main(3b28d2c, S1이 lane/economy 머지 후 combat_stats를 ShipStats로 교체) 머지.
  `economy/cards.dart`(summonCost·canSummon·nextPromotion·promotionGold·promoteStatus·canPromote·receiveCard),
  `economy/summon.dart`(rollSummonRarity·Summon 처리) — 수용 기준 5~8·11, 100만 회 분포 ±0.2%p, 천장 50회 연속 없음. economy 테스트 37개
- 승급 골드는 전투의 `stageCurve(goldBase, goldGrowth, stage)`(화물칸 배율 전)를 그대로 쓴다 — 공식 한 곳
- 다음 할 일: 5단계 MergeAllCards·PromoteCrew → 6단계 grantBossCards·오프라인

### 2026-10-14 · S2 · 스펙 승인 + 강화·선원 효과 함수 + 테이블 + UpgradePart
- 한 일:
  - 스펙(수용 기준 13개)을 쓰고 사용자 승인 → main 머지 후 `docs/specs/economy-m1.md`로 분리. 결정: ① 카드는 계약 유지(받을 때 경험치 적립, `cards`는 승급 장수)
    ② 보스 카드는 전투가 `grantBossCards`를 호출 ③ 테이블은 설계서 기준
  - `economy/ship_stats.dart`·`crew_stats.dart` 순수 함수 + 테스트 12개(테스트 먼저 실패 확인)
  - S1에 시그니처 안내: `docs/contracts/requests/economy-stats.md`. 보스 카드는 `grantBossCards(state, ctx, fleet)`, 스테이지 올리기 전 호출로 합의
  - 테이블을 설계서 기준으로: rarities 65/27/7/1 + `bossDropRates`, growth 등급별 `expToNext`·승급 카드 3/6/10/20·증표 50·`goldKills`·`bossCards`
    (모델 `crew_tables.dart` 갱신, 설계값 고정 테스트 `tables_design_test.dart`). sim 전이라 balance 리포트는 아직 없음
  - `UpgradePart` 구현 (수용 기준 1~4 + 부분 구매·모르는 부위) — economy 테스트 23개
  - 발견: check 레인 검사가 unstaged 첫 파일 경로의 첫 글자를 자르는 버그 → S1에 보고, main 136244a에서 수정
- 다음 할 일: 4단계 Summon·천장·receiveCard → 5단계 합치기·승급
- 협의: crews.json·waves.json은 S1이 고치는 중이라 건드리지 않는다(rarities/growth/ship_parts/meta만)
- 남은 문제: 최종 피해 % 보너스 합(`crewDamageBonus`)은 아직 없음

# 세부 계획: 현상금 사냥 — 탑다운 기준 (S5 리드, 2026-10-16)

- 기획: `docs/specs/platform-content-bounty.md`(규칙·표·화면) · 계약 요청: `docs/contracts/requests/platform-bounty-c1.md`(2026-10-15, 옆모습 시절)
- 바뀐 점(탑다운 전환 뒤)
  - `BattleView.mode`는 이제 화면 방식(`top`)이다. C1 요청서의 `mode: stage|bounty`는 쓰지 않고, **`BattleView.bounty: BountyView?`**(현상금 전투 중일 때만)로 바꾼다.
  - 현상금 전투도 탑다운 전장: 보스가 위에서 나와 standoff 원을 돈다(지금 보스 규칙 그대로). 무리는 없다.
  - 세이브 v6에는 `bounty` 원문 보존 자리만 있다(game_state.dart). 타입을 붙이되 **키·버전은 그대로**(v6) — 마이그레이션 없음.
- 방식: 단계마다 리뷰 브랜치 → 소유 레인 검토 → S1 머지. 엔진 몫은 `review/bounty`(S5), 나머지는 각 레인 요청서.

## 단계
| 단계 | 담당 | 할 일 | 수용 기준(테스트) |
| --- | --- | --- | --- |
| **B0 계약** | S2(engine/·save 소유) + S5 검토 | 명령 `StartBounty(bossId, tier)`·`SweepBounty(bossId, count)`·`RetreatBounty()` · 이벤트 `BountyStarted`·`BountyCleared(reward)`·`BountyFailed(damageRatio, reason: timeout|retreat|interrupted)`·`BountySwept`·`BountyTicketsRefilled` · `BountyState`{tickets, refilledOn, cleared{}, progress{}, active?} — 세이브 v6 `bounty` 키를 타입으로(없으면 기본) · `BattleView.bounty: BountyView?`{bossId, tier, ticksLeft} · `AdPlacement.bountyTicket` · 운영자 `OpSetBountyTickets`·`OpSetWeekday` | JSON 왕복(키 없음 = 기본), 옛 v6 세이브(원문 Json) 그대로 읽힘, 기존 시나리오·골든 그대로 |
| **B1 엔진 전투** | **S5**(review/bounty), 검토 S2 | 현상금 전투 모드: `StartBounty` 성공(경제가 티켓 차감) → 전장을 비우고 **보스 1마리**(그 요일 보스, 체력 = 스테이지 `tier × stagePerTier` 해역 보스 × `hpMultiplier`)를 탑다운 규칙대로(위쪽 출발 → standoff 원 돌기 → 원거리 공격) · 타이머 `boss.timeLimitSec`(+보스 시간 강화) · 본 전투 **일시정지**(스테이지·파·파밍 그대로, 골드·처치 퀘스트·피버·돌발 이벤트·상자는 현상금 중 멈춤) · 끝(처치 / 시간 초과 / 후퇴 / 배 침몰) → 이벤트 + 본 전투 복귀(같은 스테이지 파 0) · 시작 때 `active` 저장, 불러온 세이브에 `active`가 있으면 첫 틱에 실패(interrupted)·티켓 반환 · 결정론(현상금 난수는 rngSeed에서 갈라 씀) | ① 처치 → `BountyCleared` 1번, 본 전투 같은 스테이지로 ② 30초 → `BountyFailed(timeout)`·티켓 반환·`progress`에 피해 비율 ③ `RetreatBounty` → `BountyFailed(retreat)` ④ `active` 있는 세이브 → 첫 틱 `BountyFailed(interrupted)` ⑤ 현상금 중 스테이지·골드·피버·이벤트 변화 없음 ⑥ 같은 시드 = 같은 결과 ⑦ 보스가 standoff 원에 서고 모든 계열 사거리 안(기존 탑다운 테스트 재사용) · 시나리오 `scenarios/bounty_clear.yaml`·`bounty_timeout.yaml` |
| **B2 경제** | S2(요청서) | `bounty.json`(기획 3절) + 모델·검증 · 티켓 충전(현지 날짜, 상한 9) · 도전 가능 판정(요일·일요일 전부·열린 단계·티켓) · 보상 `floor(base + perTier×(t−1))`(카드 = 보유 선원 결정론, 지도 조각 = 쓸·모은 조각 둘 다) · 소탕 · 광고 티켓(하루 1) · 엔진이 부를 함수 `bountyBossHp`·`bountyReward`(grantBossCards처럼) · sim: 하루 젬 +30~120 | 기획 8절 1·2·3·5·8 + sim 하루 젬 |
| **B3 연출** | S3(요청서) | 시작 컷인 '수배 포스터'(0.8초, 기존 해역 보스 컷인 틀) · 현상금 보스는 기존 td_boss 그림 + 수배 표식 · 처치·실패 연출(보상 숫자 올라가기) · 타이머는 보스 타이머 자리 | 4기기 골든(포스터·전투·결과), 60fps 상한 유지 |
| **B4 UI** | S4(요청서) | 항해 시트 카드(오늘 보스·티켓 n/9·도전·소탕 ×N·광고 1장) · 현상금 시트(요일 7칸·단계 −/+·진행 막대) · 전투 띠 '현상금'·후퇴 버튼 · 결과 작은 창 · 빨간 점은 티켓 9장일 때만 · 태블릿 한 줄 | 기획 8절 9(골든 ko/en, 360·384dp 넘침 없음) |
| **B5 플랫폼** | S5 | 분석 `bounty_start/clear/fail/sweep`(boss·tier·reason) · 스토어 문구 한 줄 · 실기기 QA 항목 추가(아침 목록) · 앱이 뒤로 가면(광고 제외) `RetreatBounty`와 같은 처리 — AdAwareLifecycle 연결 | 분석 어댑터 단위 테스트, lifecycle 테스트(광고 중 pause는 실패 아님) |

## 순서·병행
B0(계약) → B1 ∥ B2 ∥ B3 ∥ B4(가짜 상태·운영자 명령으로) → B5 → 통합(S1, 실기기).
- B1이 B2의 `bountyBossHp`·`bountyReward`를 부른다 → B2가 함수 시그니처만 먼저 커밋(본문은 나중)하면 B1이 막히지 않는다.

## 열린 결정 (S1)
1. 현상금 중 **피버 게이지**: 멈춤(추천 — 반복 도전으로 피버를 모으는 길 차단) vs 그대로 쌓임.
2. 현상금 보스 **standoff**: 본 보스와 같은 100(추천, 테스트 재사용) vs 더 가까이(긴장감).
3. **배 침몰** 시: 실패(timeout과 같은 처리, 티켓 반환 — 추천) vs 티켓 소모.
4. 일요일 '아무 보스': 그대로(추천) vs '이번 주 덜 깬 보스 추천' 표시만.

## 영향(다른 기능과 겹치는 곳)
- 돌발 이벤트·보물상자: 현상금 중 스폰 안 함, 남은 것은 그대로 멈춤(시계 정지) — S2 economy 체크 한 줄.
- 환생 v2: 지도 조각 보상은 쓸·모은 조각 둘 다 증가.
- 오프라인 보상: 현상금 중 앱 종료 → 다음 실행은 interrupted 실패 처리가 먼저, 그 뒤 오프라인 계산(savedAt 기준 그대로).

# 요청: 현상금 사냥 C1 계약 — 명령·이벤트·광고 자리·BattleView·세이브(`bounty`, `bounty.active` 포함) (platform → S1)

- 요청 레인: platform (S5) · 날짜 2026-10-15 · 기획 `docs/specs/platform-content-bounty.md` · 분해 `docs/plans/active/platform-bounty-breakdown.md` C1
- 상태: **초안 — 구현 보류**(S1 지시: 탑다운 시험판 판정 뒤). 판정 결과 전투 구조가 바뀌면 B(BattleView)·D(복귀 규칙)를 다시 본다.
- 확정된 것: 선택 키 `bounty.active`를 둔다(S1 결정 2026-10-15). 아래 C절.
- 원칙: 계약만 정한다(타입·JSON 모양·마이그레이션). 규칙(충전·보상·판정)은 economy, 전투 모드는 battle 몫이다.

## A. 명령 (`commands.dart`, JSON `type`)
| 명령 | JSON | 필드 | 메모 |
| --- | --- | --- | --- |
| `StartBounty(bossId, tier)` | `startBounty` | `bossId: String`, `tier: int` | 요일·단계·티켓 판정은 economy. 거절 = 상태 그대로 |
| `SweepBounty(bossId, count)` | `sweepBounty` | `bossId: String`, `count: int` (≥1) | 깬 최고 단계로. 티켓이 모자라면 있는 만큼 |
| `RetreatBounty()` | `retreatBounty` | — | 도중 포기 = 실패 처리 + 티켓 반환 |
| `OpSetBountyTickets(n)` | `op.setBountyTickets` | `count: int` | 운영자 |
| `OpSetWeekday(d?)` | `op.setWeekday` | `weekday: int?` (1~7, null = 실제 요일) | 운영자. **세이브에 넣지 않는다**(엔진 메모리의 덮어쓰기 값, 앱을 다시 켜면 풀림) |

## B. 이벤트 (`events_meta.dart`, 연출용 — 상태가 진실)
| 이벤트 | JSON | 필드 |
| --- | --- | --- |
| `BountyStarted` | `bountyStarted` | `bossId, tier, timeLimitTicks` |
| `BountyCleared` | `bountyCleared` | `bossId, tier, reward: BountyReward` |
| `BountyFailed` | `bountyFailed` | `bossId, tier, damageRatio: double, reason: 'timeout' \| 'retreat' \| 'interrupted'` |
| `BountySwept` | `bountySwept` | `bossId, tier, count, reward: BountyReward` |
| `BountyTicketsRefilled` | `bountyTicketsRefilled` | `count` (이번에 늘어난 장수) |

- `BountyReward` = `{type: 'gems'|'cards'|'gifts'|'mapPieces', amount: int, crewId: String?}`(카드일 때 받은 선원). JSON 왕복.
- `reason: 'interrupted'` = 앱 종료·백그라운드로 끝난 경우(C절). 기획 AC7에서 UI 문구를 구분하려고 둔다.

## C. 세이브 — `GameState.bounty: BountyState`
```json
"bounty": {
  "tickets": 3,
  "refilledOn": "2026-10-15",
  "cleared": {"giant_hermit": 4},
  "progress": {"giant_hermit": 0.62},
  "adOn": "2026-10-15",
  "active": {"bossId": "thunder_ray", "tier": 2}
}
```
| 키 | 타입 | 필수 | 뜻 |
| --- | --- | --- | --- |
| `tickets` | int | ○ | 지금 티켓(0~상한, 광고로 상한+1까지) |
| `refilledOn` | `YYYY-MM-DD` | ○ | 마지막 충전 현지 날짜(`daily.date`와 같은 형식·비교 함수) |
| `cleared` | Map<String,int> | ○ | 보스별 깬 최고 단계(없으면 0) |
| `progress` | Map<String,double> | ○ | 다음 단계 최고 피해 비율 0~1 |
| `adOn` | 날짜? | 선택 | 광고 티켓을 받은 날 — **ads 일일 카운터가 이미 있으면 빼도 된다**(S1이 기존 `daily.ads` 구조 보고 결정) |
| `active` | `{bossId, tier}`? | **선택** | 현상금 전투 중. 티켓은 **이미 차감된 상태** |

### `bounty.active` 규칙 (왜 필요한가: 분해 문서 76행 — 앱이 죽으면 티켓만 사라진다)
1. `StartBounty` 성공 = 티켓 −1, `active` 설정, 그 틱에 저장 요청(`SaveRequested('bounty')`). 세이브에 남는다.
2. 성공·실패·후퇴로 끝나면 `active` = null(+ 실패·후퇴는 티켓 +1).
3. **불러온 세이브에 `active`가 있으면**(전투 도중 앱 종료) 엔진 첫 틱에 실패 처리: 티켓 +1, `active` null, `BountyFailed(reason: interrupted, damageRatio: 0)`. 본 전투로 시작한다.
   전투 자체(보스 체력·남은 시간)는 저장하지 않는다. 이어하기는 없다(30초짜리라 의미가 없고, 계약을 줄인다).
4. 백그라운드(`EngineHost.pause`)도 3과 같다: battle이 pause 때 `RetreatBounty`와 같은 처리를 하되, reason은 interrupted. **광고 중 pause는 제외**(AdAwareLifecycle가 이미 거른다 — 백그라운드로 치지 않음).
5. 오프라인 보상: `active` 동안의 시간은 오프라인으로 세지 않는다. `savedAt` 기준 규칙은 그대로 두고, 3이 첫 틱에 먼저 돈다.

### 마이그레이션
- 세이브 버전: **환생 v2(`platform-rebirth-v2.md`)도 v6을 쓴다.** 둘 다 승인되면 **v6 하나로 합치기**를 권한다(마이그레이션 함수·픽스처 1벌). 따로 가면 먼저 머지되는 쪽이 v6, 다른 쪽이 v7이다.
- vN−1 → vN: `bounty = {tickets: 3, refilledOn: <마이그레이션 시각의 현지 날짜>, cleared: {}, progress: {}}`(`active` 없음).
  - 현지 날짜는 마이그레이션 함수가 Clock을 모르므로 **`savedAt`의 날짜**를 쓴다. 다음 틱 충전이 '오늘 − savedAt 일수 × 3'을 더하므로 결과가 맞다.
- 픽스처 `fixtures/saves/v6.json`(현상금 진행 있음 + `active` 있음 1개 더: `v6_bounty_active.json`).

## D. BattleView (렌더·UI 읽기 전용, 세이브 아님)
- `mode: BattleMode` (`stage` | `bounty`) — JSON `'stage'|'bounty'`, 없으면 stage.
- `bountyTicksLeft: int?` — bounty일 때만. 보스 HP·이름은 기존 `enemies`(boss=true)로 충분하다.
- 본 전투 복귀 규칙: 같은 스테이지, 파 0, `farming` 그대로(환생 복귀와 같은 BattleView 초기화 함수 재사용).

## E. 광고·기타
- `AdPlacement.bountyTicket`(enum 끝에 추가 — byName JSON이라 순서 무관). `ads.json`에 placement(economy E1).
- 분석(platform 몫, 계약 아님): `bounty_start/clear/fail/sweep`에 `boss, tier, reason`.
- 환생 v2와의 접점: 현상금 보상 `mapPieces`는 **쓸 조각과 모은 조각(누계)을 둘 다** 늘린다(환생 v2 0절). 환생 v2가 먼저 머지되면 그렇게, 아니면 지금처럼 `wallet.mapPieces`만 늘린다.

## F. 완료 기준 (C1)
1. 명령 5개·이벤트 5개 JSON 왕복 테스트(필드 빠짐 없음, 알 수 없는 type은 기존처럼 FormatException).
2. `BountyState` JSON 왕복. `active` 있음·없음 둘 다. `active` 키가 없는 세이브도 읽힌다(선택 키).
3. 마이그레이션 v5→v6: 티켓 3, `refilledOn` = savedAt 날짜, 빈 맵. 기존 v1~v5 픽스처 전부 통과.
4. `active`가 있는 세이브로 엔진을 시작하면 첫 틱 뒤 티켓 +1, `active` null, `BountyFailed(interrupted)` 1개. 이 동작은 battle·economy 구현 몫이지만 **계약 테스트에 실패하는 테스트(skip 표시)로 먼저 넣어 둔다**.
5. `check --full` 통과, `docs/contracts` 문서 갱신(S1 소유 파일).

## 열린 질문 (S1)
- `adOn` 대신 기존 광고 일일 카운터로 충분한가?
- `OpSetWeekday`를 Clock 덮어쓰기로 할지, 경제 함수 인자(테스트 전용)로만 할지 — QA에서 요일 보스를 다 보려면 운영자 명령이 편하다.
- 시험판 판정이 '탑다운으로 전환'이면: 현상금 전투도 그 전장에서 돈다. `mode`·`bountyTicksLeft`만 계약이라 바뀌는 건 battle 구현뿐이다(계약은 그대로 쓸 수 있게 일부러 작게 잡았다).

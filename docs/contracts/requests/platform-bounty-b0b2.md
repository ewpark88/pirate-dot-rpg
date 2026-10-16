# 요청: 현상금 사냥 B0 계약 + B2 경제 (platform S5 → S2)

- 2026-10-16 · 계획 `docs/plans/active/platform-bounty-topdown.md`(S1 승인) · 기획 `docs/specs/platform-content-bounty.md` · 옛 C1 요청 `platform-bounty-c1.md`(이 문서가 대신함)
- 결정: 피버 멈춤 · 보스 standoff 100(본 보스와 같음) · 배 침몰 = 실패 + 티켓 반환 · 일요일 아무 보스.

## B0 계약 (먼저 — B1 엔진·B4 UI가 기다린다)
| 무엇 | 내용 |
| --- | --- |
| 명령 | `StartBounty(bossId, tier)` · `SweepBounty(bossId, count)` · `RetreatBounty()` · 운영자 `OpSetBountyTickets(n)` · `OpSetWeekday(d?)`(세이브에 안 남음) |
| 이벤트 | `BountyStarted(bossId, tier, timeLimitTicks)` · `BountyCleared(bossId, tier, reward)` · `BountyFailed(bossId, tier, damageRatio, reason: timeout\|retreat\|interrupted\|sunk)` · `BountySwept(bossId, tier, count, reward)` · `BountyTicketsRefilled(count)` · `BountyReward`{type, amount, crewId?} |
| 세이브 | v6 `bounty` 키(지금 원문 Json 보존)를 `BountyState`{tickets, refilledOn, cleared{}, progress{}, adOn?, active?{bossId, tier}}로 — **키·버전 그대로**, 키가 없으면 기본(티켓 ticketsPerDay, 오늘 날짜) |
| 화면 투영 | `BattleView.bounty: BountyView?`{bossId, tier, ticksLeft} — 선택 키(현상금 중에만, 없으면 JSON에 없음). `BattleView.mode`(top)는 건드리지 않음 |
| 광고 | `AdPlacement.bountyTicket` |
| 엔진이 부를 함수(시그니처 먼저, 본문은 B2) | `BigNum bountyBossHp(GameTables t, String bossId, int tier)` · `BountyReward bountyReward(GameState s, GameTables t, String bossId, int tier, Rng rng)` · `GameState grantBountyReward(GameState s, BountyReward r)` · `bool canStartBounty(GameState s, GameTables t, DateTime now, String bossId, int tier)` |
- 완료: JSON 왕복(키 없음 = 기본), 옛 v6 세이브 그대로 읽힘, 기존 시나리오·골든 그대로.

## B2 경제
- `packages/game_data/tables/bounty.json`(기획 3절) + 모델·검증(요일 7, 보스 id가 regions에 있음, maxTier ≥ 1).
- 티켓 충전(현지 날짜가 바뀐 첫 틱, 일수 × ticketsPerDay, 상한 ticketCap) · `StartBounty`가 티켓 −1(조건 안 맞으면 무시) · `SweepBounty` · 광고 티켓 하루 1(상한 넘어도 +1).
- 보상: `floor(base + perTier × (t − 1))`. 카드 = 보유 선원 결정론. 지도 조각 = **쓸 조각·모은 조각 둘 다**(환생 v2). 선물은 젬 10으로 대체.
- 현상금 중에는 돌발 이벤트·보물상자를 스폰하지 않는다(경제 쪽 체크 한 줄). 피버 증가는 엔진(B1)이 막는다.
- sim: 하루 젬 +30~120(기획 개요 '하루 젬 ≤ 140' 안).
- 완료: 기획 8절 1·2·3·5·8 + sim.

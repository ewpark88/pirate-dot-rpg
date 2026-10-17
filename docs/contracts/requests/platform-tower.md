# platform → S1(계약): 심연의 탑 — 세이브 tower · 명령 3 · 이벤트 4 · BattleView.tower

- 요청 레인 / 날짜: platform(S5) / 2026-10-18 · 근거: `docs/specs/platform-content-v2.md` 4절(사용자 확정 — 환생 1회 또는 스테이지 60, 도전권 1장/일 최대 3, 광고 +1).
- 바꿀 경로(공유): `game_state.dart`(+tower 선택 키), `commands.dart`·`events*.dart`(새 명령·이벤트), `battle_view.dart`(+tower 선택 키), `game_data/tables/meta.json`(+tower 표 — 수치는 S2 확정, 임시값으로 시작), ads.json placements(+towerTicket).
- 세이브 버전: 올리지 않는다 — 모두 선택 키(없으면 null/기본값), 현상금 `bounty`와 같은 방식.

## 1. 세이브 `GameState.tower: TowerState?` (키가 없으면 null → 경제가 열림 조건을 만족한 첫 틱에 채움)
| 필드 | 뜻 |
| --- | --- |
| `tickets: int` | 남은 도전권(하루 `meta.tower.ticketsPerDay` 충전, 최대 `maxTickets`) |
| `refilledOn: String?` | 마지막 충전 현지 날짜(yyyy-MM-dd) — 현상금과 같은 규칙 |
| `adOn: String?` | 광고 도전권을 받은 날짜(하루 1) |
| `best: int` | 도달한 최고 층(깬 층) |
| `firstCleared: int` | 첫 클리어 보상을 받은 가장 높은 층(이 층까지는 다시 깨도 첫 보상 없음) |
| `active: TowerActive?` | 진행 중 `{floor}` — 세이브에 남아 있으면 앱이 꺼졌던 것 → 불러올 때 중단 처리(도전권은 돌려주지 않음 — 도달 층까지 기록·상자는 준다) |

## 2. 명령 (EconomySystem이 도전권·소탕, BattleSystem이 전투)
| 명령 | 처리 |
| --- | --- |
| `StartTower()` | 열림(환생 ≥ 1 또는 최고 스테이지 ≥ `unlockStage`)·도전권 ≥ 1·현상금/탑 진행 중 아님 → 도전권 −1, `active {floor: 1}`. 아니면 무시 |
| `SweepTower()` | `best ≥ 1`·도전권 ≥ 1·진행 중 아님 → 도전권 −1, 층 `floor(best × sweepRatio)`(최소 1)의 상자 보상 즉시(첫 클리어 보상 없음) |
| `RetreatTower()` | 진행 중이면 끝(reason retreat) — 도달 층 기록·상자 |
| 광고 `towerTicket` | 기존 광고 보상 흐름(`ClaimAdReward(placement)`)에 장치 하나 — 도전권 +1(하루 1, 최대 넘어도 1장은 받음) |

## 3. 이벤트
| 이벤트 | 필드 | 쓰는 곳 |
| --- | --- | --- |
| `TowerStarted(floor)` | 시작 층 | 렌더 '심연의 탑' 띠 · UI 시트 닫기 |
| `TowerFloorCleared(floor, gems, cards)` | 깬 층, 그 층 첫 클리어 보상(없으면 0) | 렌더 '12F' 띠 · 보상 연출 |
| `TowerEnded(floor, reason, kills, chestGems, chestCards)` | 도달 층(마지막으로 깬 층), sunk·retreat·interrupted, 처치 수, 상자 | UI 결과 창 |
| `TowerSwept(floor, chestGems, chestCards)` | 소탕 층·상자 | UI 토스트 |
- 카드 보상은 기존처럼 `CardGranted(source: 'tower')`도 함께(보유 선원 중 결정론 무작위).

## 4. BattleView `tower: TowerView?` (선택 키)
`{floor, wave, waves}` — HUD '심연 12층 · 2/3파'. 탑 중엔 보스 버튼·피버 게이지·돌발 이벤트를 숨긴다(UI).

## 5. 전투 규칙(엔진, 계약 밖 — 참고)
- 탑 중 본 전투(스테이지·골드·피버·돌발·도전·빠른 항해)는 멈춘다(현상금과 같음). 끝나면 같은 스테이지 빈 바다·배 수리로 돌아간다.
- 층 = 무리 파 `wavesPerFloor`(3). 마리 수 = `baseCount × countGrowth^(층−1)`(상한 `maxCount`), 적 = 그 층 기준 스테이지(`max(1, floor(최고 스테이지 × stageRatio)) + 층`)의 보통 무리 한 마리 값, **골드 없음**. 3파째는 고리(ring) 패턴. `bossEvery`(5)층마다 마지막에 순환 보스.
- 층을 깨면 배 체력 `healRatio` 회복. 침몰 → 끝.
- '장면 모드' 공통부: 현상금·탑(뒤에 보스 러시·요일 던전)이 같은 틀(`SceneMode`: prepare·resolve·retreat)을 쓴다 — battle_system은 목록만 돈다.

## 6. 표 `meta.tower` (임시값 — S2 확정)
`unlockStage 60 · ticketsPerDay 1 · maxTickets 3 · wavesPerFloor 3 · baseCount 20 · countGrowth 1.25 · maxCount 200 · stageRatio 0.8 · bossEvery 5 · healRatio 0.2 · sweepRatio 0.8 · firstGems 10 · cardEvery 5 · chest [{floor 1, gems 20}, {floor 10, gems 50, cards 1}, {floor 20, gems 100, cards 2}, {floor 30, gems 150, cards 3}]`

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:

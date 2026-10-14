# 스펙: 하단 탭 화면 1차 (배 강화 · 소환 · 원정대 · 상단 HUD)

- 상태: 승인됨 (2026-10-14, S1 — 사용자 위임 확인) · 레인: ui · 설계서 절: 4.2 · 4.3 · 4.5 · 4.9 · 4.12

## 목적
- 단순한가: 탭마다 누를 버튼은 1~2종(강화 / 소환 / 승급). 모든 버튼은 `Command` 하나만 보낸다.
- 피로가 없는가: 탭 4개 고정, 팝업 없음(이번 범위), 빨간 점은 “지금 누르면 이득”인 승급에만.
- 공정한가: 소환 탭에 확률표·천장 진행을 `rarities.json` 값 그대로 보인다.

## 규칙
1. 화면은 `GameState` 하나만 구독한다(Riverpod `gameStateProvider`). 개발·테스트에서는 `fixtures/states/*.json`을 주입한다.
2. 버튼은 `CommandSink`(UI 레인 안의 얇은 인터페이스, 나중에 `GameEngine.enqueue`에 연결)로 `Command`만 보낸다. UI는 상태를 직접 바꾸지 않는다.
3. 숫자 표시는 `BigNum.format()`만 쓴다. 문구는 `parts/ui.*.arb`(키 접두어 `ui`)와 테이블 `nameKey`.
4. 강화 효과·비용은 경제 함수(`partEffect`·`partCost`, `game_core.dart`)로 표시한다. UI에 계산식을 두지 않는다. 승급 조건·비용, 소환 젬 비용은 경제 레인이 공개할 때까지 `TODO(economy)` 자리로 둔다.
5. 등급은 `rarityOfLevel`(경제 함수)로 표시한다.

## 화면
- **상단 HUD**: 골드 · 젬 · 스테이지(`stage`, 웨이브) · 보스 타이머(`battle.bossActive`일 때 남은 초 = `bossTicksLeft × tickMs`) · 함성 게이지(`progress.rage`, `skills.json` rage.max 기준). 가득 차면 궁극기 버튼 활성 → `TriggerUltimate`.
- **배 탭**: `ship_parts.json` 순서로 5줄 — 이름(nameKey) · `Lv N`(maxLevel 있으면 `N/최대`) · 현재 효과(공격력·HP는 `BigNum.format()`, 속도·골드는 `×1.85`, 치명타는 `17%`) · 비용 버튼(`partCost`). 버튼 누르면 `UpgradePart(id)`. 최대 레벨이거나 골드가 비용보다 적으면 버튼 비활성. (꾹 눌러 연속·자동 강화 토글은 다음 계획)
- **소환 탭**: `Summon(count: 1)` / `Summon(count: 10)` 버튼, 확률표(등급별 `summonRate`), 천장 막대 `pityCount / pity.count`와 “N회 안에 영웅 이상 확정”. 젬 비용은 TODO(economy) — 버튼은 항상 활성(엔진이 거절).
- **선원(원정대) 탭**: 40명 격자(`crews.json` num 순) — 미보유는 흐리게, 보유는 등급 색 테두리·별·`Lv`·카드 수. 출전 중 선원(`battle.fleet`)은 표시. 일괄 합치기 → `MergeAllCards`. 레벨이 등급 상한(신화 제외)이면 승급 버튼 + 빨간 점 → `PromoteCrew(id)` (카드·골드 충족 판정은 TODO(economy)). 도감 진척 `collection.length / 40`.
- **항해 탭**: 이번 범위 밖(기존 전장 자리 유지).

## 수용 기준 (Given / When / Then) — 각각 위젯 테스트 1개 이상
1. Given `stage37_midgame` When 앱을 그린다 Then HUD에 골드 `1.25M`, 젬 `140`, 스테이지 `37`이 보인다.
2. Given `boss_fight` When 그린다 Then 보스 남은 초가 보인다 / Given `new_player` Then 보스 타이머가 없다.
3. Given 함성 < 최대 Then 궁극기 버튼 비활성 / Given 함성 = 최대 When 누르면 Then `TriggerUltimate` 1개가 전송된다.
4. Given `stage37_midgame` When 배 탭 Then 부위 5줄과 각 레벨(대포 Lv52 등)이 보이고, 대포 버튼을 누르면 `UpgradePart('cannon')`이 전송된다.
5. Given 부위가 maxLevel(`all_crews_mythic`의 돛) 또는 골드 부족(`new_player`) Then 그 부위 버튼은 비활성.
6. Given 소환 탭 When 1회/10회를 누르면 Then `Summon(count:1)`/`Summon(count:10)`. 천장 `17/50`과 확률 4줄이 보인다.
7. Given 선원 탭 Then 카드 40장, 보유 수 = `collection` 수. 일괄 합치기 → `MergeAllCards`.
8. Given 레벨이 등급 상한인 보유 선원 Then 승급 버튼이 보이고 누르면 `PromoteCrew(id)` / Given `all_crews_mythic` Then 승급 버튼이 없다.
9. 영어 골든 4장(HUD+배 탭 · 소환 · 선원 · 보스전 HUD), `stage37_midgame`/`boss_fight` 기준. 한국어 텍스트 테스트는 위 기준으로 대신한다.

## 문구 (ko / en) — `parts/ui.*.arb`
| 키 | ko | en |
| --- | --- | --- |
| uiHudGold / uiHudGems | 골드 / 젬 | Gold / Gems |
| uiHudStage | 스테이지 {stage}-{wave} | Stage {stage}-{wave} |
| uiHudBossTimer | 보스 {seconds}초 | Boss {seconds}s |
| uiHudUltimate | 궁극기 | Ultimate |
| uiLevel / uiLevelMax | Lv {level} / Lv {level}/{max} | Lv {level} / Lv {level}/{max} |
| uiShipUpgrade | 강화 | Upgrade |
| uiShipMaxed | 최대 | MAX |
| uiSummonOne / uiSummonTen | 1회 소환 / 10회 소환 | Summon x1 / Summon x10 |
| uiSummonRates | 등급 확률 | Rates |
| uiSummonPity | {count}회 안에 {rarity} 이상 확정 | {rarity}+ guaranteed within {count} |
| uiCrewMergeAll | 일괄 합치기 | Merge All |
| uiCrewPromote | 승급 | Promote |
| uiCrewCollection | 도감 {owned}/{total} | Collection {owned}/{total} |
| uiCrewCards | 카드 {count} | Cards {count} |
| uiCrewDeployed | 출전 | Deployed |
| uiPending | — | — |
| uiEffectMultiplier / uiPercent | ×{value} / {value}% | ×{value} / {value}% |

## 운영자 모드에서 불러보는 법
- 이번 범위: 운영자 패널에 “샘플 상태 불러오기(4종)” 버튼 → `gameStateProvider`에 픽스처 주입. (6.10 다른 묶음은 별도 계획)


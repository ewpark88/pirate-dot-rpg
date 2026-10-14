# economy: 전투가 쓰는 강화·선원 효과 함수 시그니처 (+ 보스 카드 연결)

- 요청 레인 / 날짜: economy (S2) / 2026-10-14
- 바꿀 계약: **없음** — 경제 레인 소유 코드(`packages/game_core/lib/src/economy/`)의 공개 함수 안내. 같은 패키지라 전투가 바로 import한다.

## 왜 필요한가
S1 요청: 전투의 `battle/combat_stats.dart` 임시 공식을 경제 함수로 바꾸기 위해. 공식이 한 곳에만 있어야 sim·전투·UI 숫자가 같다.

## 제안 (lane/economy에 구현·테스트 완료: `test/economy/stats_test.dart`)

```dart
// package:game_core/src/economy/ship_stats.dart  — 모두 ship_parts.json에서 읽음
BigNum partEffect(ShipPartDef def, int level);          // exp/linear × milestoneMultiplier^floor(Lv/milestoneEvery)
BigNum partCost(ShipPartDef def, int level);            // costBase × costGrowth^Lv (Lv → Lv+1)
BigNum shipAttack(ShipPartsTable t, int level);         // 대포 4×1.11^Lv ×2^floor(Lv/25)
BigNum shipMaxHp(ShipPartsTable t, int level);          // 선체 60×1.12^Lv ×2^floor(Lv/25)
double attackSpeedMultiplier(ShipPartsTable t, int level); // 돛 1+0.05Lv, min(caps.attackSpeedMax)
double critChance(ShipPartsTable t, int level);         // 망루 0.05+0.01Lv, min(caps.critChanceMax)
double goldMultiplier(ShipPartsTable t, int level);     // 화물칸 (1+0.1Lv) ×2^floor(Lv/25)

class ShipStats {                                        // ShipStats.of(tables.shipParts, state.ship)
  BigNum attack, maxHp; double attackSpeed, critChance, critMultiplier, goldMultiplier, skillCooldownMinSec;
}

// package:game_core/src/economy/crew_stats.dart
RarityDef rarityOfLevel(RarityTable t, int level);      // 레벨 구간 → 등급
int promotionCount(RarityTable t, int level);           // 일반 0 … 신화 4
double crewPowerMultiplier(GrowthTable g, RarityTable t, int level); // (1+0.08(Lv-1)) × 1.35^승급
```

- 최종 피해의 나머지 항(배 등급 `ship_tiers.damageBonus`, % 보너스 합: 보유 효과·도감·지도 조각)은 다음 단계에서
  `crewDamageBonus(GameTables, GameState)` 하나로 추가할 예정 — 나오면 이 문서에 덧붙인다.

### 소환·승급 판정 (UI 레인용, 4단계에서 추가)

```dart
// package:game_core/src/economy/cards.dart
int summonCost(MetaTable meta, int count);                       // 젬
bool canSummon(GameState s, GameTables t, int count);
PromotionDef? nextPromotion(GameTables t, int level);            // 신화면 null
BigNum promotionGold(GameTables t, PromotionDef p, int stage);   // 처치 골드(화물칸 전) × goldKills
enum PromoteStatus { ok, notOwned, maxRarity, level, cards, gold, tokens }
PromoteStatus promoteStatus(GameState s, GameTables t, String crewId); // 빨간 점 = ok
bool canPromote(GameState s, GameTables t, String crewId);
GameState receiveCard(GameState s, GameTables t, String crewId, String rarity); // 카드 1장 받기 공통 규칙

// package:game_core/src/economy/summon.dart
String rollSummonRarity(RarityTable t, Rng rng, {required bool pity});
```
`game_core.dart` export에 `cards.dart`도 추가해 주면 UI가 `src/` import 없이 쓴다(shared 경로라 S1 몫).

### 보스 카드 (사용자 결정 ②, 2026-10-14)
경제 시스템은 전투 이벤트를 받지 못하므로, **전투가 보스 처치 순간 경제 함수를 부른다**:

```dart
// package:game_core/src/economy/cards.dart — 구현됨 (6단계)
GameState grantBossCards(GameState state, SystemContext ctx, List<String> fleet);
// 스테이지 1~10은 2장, 이후 1+floor(stage/150)장 — state.progress.stage(잡은 스테이지) 기준
// 카드 대상 = fleet(출전 선원) 중 무작위, 처음 10번은 옥토. 등급은 rarities.bossDropRates.
```
합의(S1, 2026-10-14): 스테이지를 올리기 **전**에 부른다. 순서: `BossCleared` emit → 젬 지급 → `grantBossCards` → 스테이지+1·`StageAdvanced`.

### 오프라인·초당 골드 추정 (6단계, sim·UI 복귀 팝업용)

```dart
// package:game_core/src/economy/offline.dart — export 요청
BigNum fleetDps(GameState s, GameTables t, List<String> fleet);          // 단일 대상 DPS 추정
BigNum goldPerSecEstimate(GameState s, GameTables t, List<String> fleet); // 설계서 4.7
List<String> offlineFleet(GameState s, GameTables t);                     // autoFleet(지금 슬롯)
```

## 그동안 쓰는 임시 어댑터
없음. 전투는 머지 전까지 `combat_stats.dart` 임시 공식을 쓰고, 머지 후 위 함수로 교체.

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:

import 'package:game_core/src/battle/spawner.dart' show stageCurve;
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/crew_stats.dart';
import 'package:game_core/src/economy/rebirth_shop.dart' show crewMaxLevel;
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

export 'package:game_core/src/economy/ads.dart' show addAutoUpgrade, autoUpgradeRemaining;
export 'package:game_core/src/economy/auto_upgrade.dart' show autoUpgradePick;
export 'package:game_core/src/economy/bonuses.dart' show damageBonus, ownedBonus;
export 'package:game_core/src/economy/boss_preview.dart';
export 'package:game_core/src/economy/bounty.dart';
export 'package:game_core/src/economy/bounty_flow.dart' show bountyActive;
export 'package:game_core/src/economy/crew_attack.dart';
export 'package:game_core/src/economy/crew_growth.dart';
export 'package:game_core/src/economy/dex.dart';
export 'package:game_core/src/economy/fast_sail_supply.dart';
export 'package:game_core/src/economy/fever.dart'
    show addFever, feverDamageBonus, feverGoldMultiplier, feverKillsAt, feverOn, feverStep;
export 'package:game_core/src/economy/formation.dart' show activeFleet, autoFleet, emptySlotCount, fleetSlots;
export 'package:game_core/src/economy/gold_cap.dart';
export 'package:game_core/src/economy/power.dart' show FleetPower, UpgradePreview, fleetPower, previewUpgrade;
export 'package:game_core/src/economy/rebirth_forecast.dart' show RebirthForecast, rebirthForecast;
export 'package:game_core/src/economy/rebirth_shop.dart'
    show
        RebirthShopView,
        ShopItemView,
        beyondHonor,
        crewMaxLevel,
        fastSailFraction,
        offlineMaxSec,
        rebirthChest,
        shopCost,
        shopEffect,
        shopLevel,
        shopRowUnlocked,
        shopSpent,
        shopView,
        startLevel,
        treasureGoldMultiplier,
        treasureHpMultiplier,
        treasurePiecesMultiplier,
        treasureSeasUnlocked,
        upgradeCostMultiplier;
export 'package:game_core/src/economy/sea_events.dart' show stormGoldMultiplier;

// 소환 비용·승급 판정·카드 받기 (설계서 4.3.1, 4.3.3). UI가 버튼 상태에 그대로 쓴다.

/// [count]회 소환에 드는 젬.
int summonCost(MetaTable meta, int count) => meta.summonCostGems * count;

/// 첫 10연 무료인가 (설계서 4.9·4.12 튜토리얼 4단계 ‘보스 처치, 젬 획득’ 뒤, `meta.tutorial`):
/// 튜토리얼 보스(`waves.boss.tutorialFailStage`, 3단계에서 일부러 실패)를 잡았고, 아직 한 번도 소환하지 않았고,
/// `firstTenCount`연. 그 전에 주면 영웅 카드로 3단계 실패가 사라진다.
bool isFreeFirstTen(GameState state, GameTables t, int count) {
  final tut = t.meta.raw.obj('tutorial');
  return tut.boolean('firstTenSummonFree') &&
      state.progress.bestStage > t.waves.tutorialFailStage &&
      state.summonsTotal == 0 &&
      count == tut.integer('firstTenCount');
}

/// 이 상태에서 [count]회 소환에 실제로 드는 젬 (첫 10연 무료 반영). UI 버튼 표시용.
int summonCostFor(GameState state, GameTables t, int count) =>
    isFreeFirstTen(state, t, count) ? 0 : summonCost(t.meta, count);

/// [count]회 소환할 수 있는가.
bool canSummon(GameState state, GameTables t, int count) =>
    count > 0 && state.wallet.gems >= summonCostFor(state, t, count);

/// Lv[level] 선원의 다음 승급. 신화면 null.
PromotionDef? nextPromotion(GameTables t, int level) {
  final from = rarityOfLevel(t.rarities, level).id;
  final found = t.growth.promotions.where((p) => p.from == from);
  return found.isEmpty ? null : found.first;
}

/// 승급 골드 = [stage] 일반 몬스터 처치 골드(화물칸 배율 전) × [PromotionDef.goldKills].
BigNum promotionGold(GameTables t, PromotionDef p, int stage) =>
    stageCurve(t.waves.goldBase, t.waves.goldGrowth, stage).times(p.goldKills);

/// 승급 버튼 상태. [ok]가 아니면 무엇이 모자란지.
enum PromoteStatus { ok, notOwned, maxRarity, level, cards, gold, tokens }

PromoteStatus promoteStatus(GameState state, GameTables t, String crewId) {
  final crew = state.crews[crewId];
  if (crew == null) return PromoteStatus.notOwned;
  final p = nextPromotion(t, crew.level);
  if (p == null) return PromoteStatus.maxRarity;
  if (crew.level < p.level) return PromoteStatus.level;
  if (crew.cards < p.cards) return PromoteStatus.cards;
  if (state.wallet.gold < promotionGold(t, p, state.progress.stage)) return PromoteStatus.gold;
  if (state.tokens < p.tokens) return PromoteStatus.tokens;
  return PromoteStatus.ok;
}

bool canPromote(GameState state, GameTables t, String crewId) => promoteStatus(state, t, crewId) == PromoteStatus.ok;

/// 합치기로 [crew]의 레벨이 하나 오르는가: 등급 마지막 레벨(승급 문) 전이고 적립 경험치가 그 등급 `expToNext` 이상.
/// [maxLevel]은 선원 최대 레벨(crewMaxLevel, 환생 해금으로 75 → 90) — 마지막 등급(신화)은 levelMax를 넘어 그때까지 오른다.
bool canLevelUp(CrewState crew, GameTables t, {int? maxLevel}) {
  final rarity = rarityOfLevel(t.rarities, crew.level);
  final need = t.growth.expToNext[rarity.id] ?? 0;
  final last = identical(rarity, t.rarities.rarities.last);
  final cap = last ? (maxLevel ?? t.growth.maxLevel) : rarity.levelMax;
  return crew.level < cap && need > 0 && crew.exp >= need;
}

/// 일괄 합치기(MergeAllCards)로 레벨이 오르는 선원이 있는가 — UI 선원 탭 ‘할 일’ 점(매 틱 호출, 할당 없음).
bool canMergeAny(GameState state, GameTables t) {
  final max = crewMaxLevel(state, t);
  for (final c in state.crews.values) {
    if (canLevelUp(c, t, maxLevel: max)) return true;
  }
  return false;
}

/// 카드 한 장 받기 (소환·보스·오프라인 공통, 스펙 결정 ①, 사용자 결정 A).
/// - 처음 보는 선원: 카드 등급 첫 레벨로 보유 + 도감
/// - 카드 등급이 현재 등급보다 높음: 그 등급 첫 레벨로 점프(경험치 0)
/// - 신화 최고 레벨: 증표
/// - 그 외: 카드 등급 경험치 적립. 장수는 다음 승급에 필요한 만큼까지만 쌓고, 넘는 장수는 증표(신화는 모두 증표)
GameState receiveCard(GameState state, GameTables t, String crewId, String rarity) {
  final card = t.rarities.byId(rarity);
  final crew = state.crews[crewId];
  if (crew == null) {
    return state.copyWith(
      crews: {
        ...state.crews,
        crewId: CrewState(level: card.levelMin),
      },
      collection: {...state.collection, crewId},
    );
  }
  final current = rarityOfLevel(t.rarities, crew.level);
  if (t.rarities.rarities.indexOf(card) > t.rarities.rarities.indexOf(current)) {
    return state.copyWith(
      crews: {
        ...state.crews,
        crewId: crew.copyWith(level: card.levelMin, exp: 0),
      },
    );
  }
  if (crew.level >= crewMaxLevel(state, t)) return state.copyWith(tokens: state.tokens + t.growth.tokenPerSurplusCard);
  final need = nextPromotion(t, crew.level)?.cards ?? 0;
  final surplus = crew.cards >= need;
  return state.copyWith(
    tokens: surplus ? state.tokens + t.growth.tokenPerSurplusCard : null,
    crews: {
      ...state.crews,
      crewId: crew.copyWith(
        exp: crew.exp + (t.growth.cardExp[rarity] ?? 0),
        cards: surplus ? crew.cards : crew.cards + 1,
      ),
    },
  );
}

/// [receiveCard] + CardGranted 이벤트 (렌더가 카드가 날아와 모이는 연출, S3 요청). [source]는 CardGranted 참고.
GameState grantCard(GameState state, SystemContext ctx, String crewId, String rarity, String source) {
  ctx.emit(
    CardGranted(ctx.tick, crewId: crewId, rarity: rarity, source: source, isNew: !state.crews.containsKey(crewId)),
  );
  return receiveCard(state, ctx.tables, crewId, rarity);
}

/// 등급 확률표 [rates]로 한 번 굴린다 (보스·오프라인 드롭).
String rollRarity(Map<String, double> rates, Rng rng) {
  var u = rng.nextDouble();
  for (final e in rates.entries) {
    u -= e.value;
    if (u < 0) return e.key;
  }
  return rates.keys.last;
}

/// 보스 처치 카드 (설계서 4.3.3, 스펙 결정 ②). 전투가 스테이지를 올리기 **전**에 부른다.
/// - 첫 회차(환생 0): 스테이지 `starterFirstStage`부터 `starterEvery`번째 보스마다 그 보스의 카드 대신 `starterCrew`에게 일반 카드 1장
///   (사용자 결정 C). 사이 보스는 아래 규칙대로
/// - 장수: `growth.bossCards.countAt(잡은 스테이지)`, 대상: [fleet] 중 무작위, 등급: `rarities.bossDropRates`
GameState grantBossCards(GameState state, SystemContext ctx, List<String> fleet) {
  final t = ctx.tables;
  final b = t.growth.bossCards;
  final stage = state.progress.stage;
  if (state.progress.rebirths == 0 && b.isStarterStage(stage)) {
    return grantCard(state, ctx, b.starterCrew, t.rarities.rarities.first.id, 'boss');
  }
  if (fleet.isEmpty) return state;
  // 환생 뒤 이미 깬 스테이지는 줄여서 (회차 수만큼 카드 수입이 곱해지지 않게).
  final repeat = state.progress.rebirths > 0 && stage < state.progress.bestStage;
  final n = repeat ? b.repeatCountAt(stage) : b.countAt(stage);
  var s = state;
  for (var i = 0; i < n; i++) {
    s = grantCard(s, ctx, fleet[ctx.rng.nextInt(fleet.length)], rollRarity(t.rarities.bossDropRates, ctx.rng), 'boss');
  }
  return s;
}

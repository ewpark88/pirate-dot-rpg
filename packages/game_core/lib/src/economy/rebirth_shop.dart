import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';
import 'package:meta/meta.dart';

export 'package:game_core/src/economy/rebirth_rewards.dart';

// 환생 v2 (docs/specs/platform-rebirth-v2.md): 보물지도 상점·스킨·칭호·항로. 수치는 meta.rebirth.

List<JsonReader> _shop(GameTables t) => t.meta.rebirth.objs('shop');

JsonReader? _item(GameTables t, String id) {
  for (final i in _shop(t)) {
    if (i.str('id') == id) return i;
  }
  return null;
}

/// 상점 [id]의 지금 레벨.
int shopLevel(GameState s, String id) => s.rebirthShop[id] ?? 0;

/// [id]를 [level] → level + 1로 올리는 비용 `ceil(costBase × costGrowth^level)`.
int shopCost(GameTables t, String id, int level) {
  final i = _item(t, id)!;
  var c = i.number('costBase');
  for (var l = 0; l < level; l++) {
    c *= i.number('costGrowth');
  }
  return c.ceil();
}

/// 상점에 쓴 조각 누계 (줄 해금 기준).
int shopSpent(GameState s, GameTables t) {
  var sum = 0;
  for (final e in s.rebirthShop.entries) {
    if (_item(t, e.key) == null) continue;
    for (var l = 0; l < e.value; l++) {
      sum += shopCost(t, e.key, l);
    }
  }
  return sum;
}

/// [row]줄(1부터)이 열렸는가: 상점에 쓴 누계 ≥ `shopRows[row − 1]`.
bool shopRowUnlocked(GameState s, GameTables t, int row) {
  final rows = t.meta.rebirth.raw['shopRows'] as List;
  return row >= 1 && row <= rows.length && shopSpent(s, t) >= (rows[row - 1] as num);
}

/// 상점 항목 효과 = 레벨 × `perLevel` (항목마다 단위가 다르다: 시작 레벨·비율·초·칸).
double shopEffect(GameState s, GameTables t, String id) {
  final i = _item(t, id);
  return i == null ? 0 : shopLevel(s, id) * i.number('perLevel');
}

@immutable
class ShopItemView {
  const ShopItemView({
    required this.id,
    required this.row,
    required this.level,
    required this.maxLevel,
    required this.cost,
    required this.unlocked,
    required this.affordable,
    required this.effectNow,
    required this.effectNext,
    required this.nameKey,
    required this.descKey,
    this.effectNowMinor,
    this.effectNextMinor,
  });

  final String id;
  final int row;
  final int level;
  final int maxLevel;

  /// 다음 레벨 비용. 상한이면 null.
  final int? cost;
  final bool unlocked;
  final bool affordable;
  final double effectNow;

  /// 다음 레벨 효과. 상한이면 null.
  final double? effectNext;

  /// 두 번째 효과값이 있는 항목만 (startParts: 돛·망루 시작 레벨 = 레벨 × perLevelMinor). 없으면 null.
  final double? effectNowMinor;
  final double? effectNextMinor;
  final String nameKey;
  final String descKey;
}

@immutable
class RebirthShopView {
  const RebirthShopView({required this.items, required this.spentTotal, required this.nextRowAt});

  final List<ShopItemView> items;
  final int spentTotal;

  /// 다음 잠긴 줄이 열리는 쓴 누계. 다 열렸으면 null.
  final int? nextRowAt;

  /// 지금 살 수 있는 칸이 있다 (항해 탭 빨간 점).
  bool get anyAffordable => items.any((i) => i.affordable);
}

/// 상점 화면 (UI는 표시용 계산을 하지 않는다).
RebirthShopView shopView(GameState s, GameTables t) {
  final spent = shopSpent(s, t);
  final rows = [for (final r in t.meta.rebirth.raw['shopRows'] as List) (r as num).toInt()];
  final items = [
    for (final i in _shop(t))
      () {
        final id = i.str('id');
        final level = shopLevel(s, id);
        final max = i.integer('maxLevel');
        final row = i.integer('row');
        final cost = level < max ? shopCost(t, id, level) : null;
        final unlocked = spent >= rows[row - 1];
        return ShopItemView(
          id: id,
          row: row,
          level: level,
          maxLevel: max,
          cost: cost,
          unlocked: unlocked,
          affordable: unlocked && cost != null && s.wallet.mapPieces >= cost,
          effectNow: level * i.number('perLevel'),
          effectNext: cost == null ? null : (level + 1) * i.number('perLevel'),
          nameKey: i.str('nameKey'),
          descKey: i.str('descKey'),
          effectNowMinor: i.has('perLevelMinor') ? level * i.number('perLevelMinor') : null,
          effectNextMinor: i.has('perLevelMinor') && cost != null ? (level + 1) * i.number('perLevelMinor') : null,
        );
      }(),
  ];
  final next = rows.where((r) => r > spent).firstOrNull;
  return RebirthShopView(items: items, spentTotal: spent, nextRowAt: next);
}

GameState buyRebirthUpgrade(GameState s, BuyRebirthUpgrade c, SystemContext ctx) {
  final t = ctx.tables;
  final item = shopView(s, t).items.where((i) => i.id == c.id).firstOrNull;
  if (item == null || !item.affordable) return s;
  ctx
    ..emit(RebirthUpgradeBought(ctx.tick, id: c.id, level: item.level + 1))
    ..emit(SaveRequested(ctx.tick, reason: 'rebirthShop'));
  return s.copyWith(
    wallet: s.wallet.copyWith(mapPieces: s.wallet.mapPieces - item.cost!),
    rebirthShop: {...s.rebirthShop, c.id: item.level + 1},
  );
}

GameState selectShipSkin(GameState s, SelectShipSkin c) {
  final id = c.id;
  if (id != null && !s.ship.skinsOwned.contains(id)) return s;
  return s.copyWith(
    ship: s.ship.copyWith(skin: id, clearSkin: id == null, skinChosen: true),
  );
}

GameState selectTitle(GameState s, SelectTitle c) {
  final id = c.id;
  if (id != null && !s.progress.titles.contains(id)) return s;
  return s.copyWith(settings: s.settings.withTitle(id));
}

/// 환생 횟수로 열린 보물 바다 해역 최대 번호 (0 = 없음).
int treasureSeasUnlocked(GameState s, GameTables t) {
  var max = 0;
  for (final u in t.meta.rebirth.objs('unlocks')) {
    if (u.str('kind') == 'treasureSea' && s.progress.rebirths >= u.integer('rebirths')) {
      final v = u.integer('value');
      if (v > max) max = v;
    }
  }
  return max;
}

GameState setTreasureRoute(GameState s, SetTreasureRoute c, SystemContext ctx) {
  final sea = c.sea;
  if (sea != null && (sea < 1 || sea > treasureSeasUnlocked(s, ctx.tables))) return s;
  return s.copyWith(
    progress: s.progress.copyWith(treasureRoute: sea, clearTreasureRoute: sea == null),
  );
}

GameState opGrantPieces(GameState s, OpGrantPieces c) => s.copyWith(
  wallet: s.wallet.copyWith(mapPieces: s.wallet.mapPieces + c.count),
  progress: s.progress.copyWith(mapPiecesEarned: s.progress.mapPiecesEarned + c.count),
  operator: true,
);

GameState opSetRebirths(GameState s, OpSetRebirths c) =>
    s.copyWith(progress: s.progress.copyWith(rebirths: c.count), operator: true);

/// 환생 횟수에 맞는 스킨·칭호와 명예 배 등급을 채운다 (세이브 v6 소급·운영자, 이벤트·상자 없음). 바뀔 것이 없으면 그대로.
GameState ensureRebirthRewards(GameState s, GameTables t) {
  final r = t.meta.rebirth;
  final n = s.progress.rebirths;
  final skins = [
    for (final k in r.objs('skins'))
      if (n >= k.integer('rebirths')) k.str('id'),
  ];
  final titles = [
    for (final k in r.objs('titles'))
      if (n >= k.integer('rebirths')) k.str('id'),
  ];
  final tier = t.shipTiers.tiers.indexOf(t.shipTiers.tierAt(s.progress.bestStage));
  final ship = s.ship;
  final needSkins = skins.any((k) => !ship.skinsOwned.contains(k));
  final needTitles = titles.any((k) => !s.progress.titles.contains(k));
  final needTier = tier > ship.honorTier;
  final needEquip = ship.skin == null && !ship.skinChosen && skins.isNotEmpty;
  if (!needSkins && !needTitles && !needTier && !needEquip) return s;
  final owned = {...ship.skinsOwned, ...skins};
  return s.copyWith(
    ship: ship.copyWith(
      skinsOwned: owned,
      honorTier: needTier ? tier : null,
      skin: needEquip ? skins.first : null,
    ),
    progress: needTitles
        ? s.progress.copyWith(titles: [...s.progress.titles, ...titles.where((k) => !s.progress.titles.contains(k))])
        : null,
  );
}

// ── 상점 효과 (환생 v2 1절). 전투·오프라인·강화가 이 함수들만 부른다. ──

/// 배 강화 골드 비용 배율 (discount: 레벨당 −perLevel).
double upgradeCostMultiplier(GameState s, GameTables t) => 1 - shopEffect(s, t, 'discount');

/// 오프라인 보상 최대 시간(초) = meta.offline.maxSec + offline 효과. 오프라인 보상·상자 추정·platform 알림이 같은 값을 쓴다.
int offlineMaxSec(GameState s, GameTables t) {
  // 유료 '넉넉한 화물 지도'(offline12, 영구): 기본 상한을 iap.offlineHours로(상점 효과는 그 위에 더한다).
  final bought = s.entitlements['offline12']?.activeAt(s.savedAt) ?? false;
  final base = bought ? t.iap.offlineHours * Duration.secondsPerHour : t.meta.offlineMaxSec;
  return (base > t.meta.offlineMaxSec ? base : t.meta.offlineMaxSec) + shopEffect(s, t, 'offline').round();
}

/// 빠른 항해 범위 (waves.rebirthSkip.fraction + fastSail).
double fastSailFraction(GameState s, GameTables t) => t.waves.rebirthSkip.fraction + shopEffect(s, t, 'fastSail');

/// 보스 제한 시간 추가(초).
/// 보물지도 상점 'bossTime'(id는 세이브 호환으로 유지) = 철갑판: 보스전·현상금에서 배가 받는 피해 비율 감소
/// (보스 시간 제한이 없어져 '보스 시간 +초' 대신, S1 결정 2026-10-17). 0.04/레벨, 최대 5 = 0.2.
double bossGuard(GameState s, GameTables t) => shopEffect(s, t, 'bossTime');

/// 출전 칸 추가.
int fleetSlotBonus(GameState s, GameTables t) => shopEffect(s, t, 'fleetSlot').round();

/// 치명타 확률 추가(배 상한 critChanceMax는 그대로), 치명타 배수 추가.
double critChanceBonus(GameState s, GameTables t) => shopEffect(s, t, 'critChance');
double critDamageBonus(GameState s, GameTables t) => shopEffect(s, t, 'critDamage');

/// 환생 조각 배율 (pieceGain).
double pieceGainMultiplier(GameState s, GameTables t) => 1 + shopEffect(s, t, 'pieceGain');

/// 환생 직후 부위 시작 레벨 (startParts: 대포·선체·화물 perLevel, 돛·망루 perLevelMinor). 부위 최대 레벨을 넘지 않는다.
int startLevel(GameState s, GameTables t, String part) {
  final i = _item(t, 'startParts');
  if (i == null) return 0;
  final minor = part == 'sail' || part == 'crowsnest';
  final n = shopLevel(s, 'startParts') * (minor ? i.number('perLevelMinor') : i.number('perLevel')).round();
  final max = t.shipParts.byId(part).maxLevel;
  return max != null && n > max ? max : n;
}

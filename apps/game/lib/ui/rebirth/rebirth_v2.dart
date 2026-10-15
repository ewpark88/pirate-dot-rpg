import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 환생 v2 화면용 보기 모델 (스펙 platform-rebirth-v2 7장 — 승인 2026-10-15).
// 경제 계약(shopView·rebirthForecast·RebirthDone 확장·스킨·칭호·보물 바다)이 오기 전까지 [RebirthV2Controller]가
// 스펙 표 숫자로 흉내 낸다. 계약이 오면 컨트롤러만 코어 함수·명령으로 바꾸고 화면은 그대로 둔다.

/// 상점 효과 표시 단위 — 숫자 옆에 붙는 꼴(ARB `uiShopFx*`).
enum ShopFx { levels, down, sec, hour, pp, plus, slots, percent }

/// 상점 칸 정의 (스펙 1장 표). 계약이 오면 `rebirth.json` `shop`이 대신한다.
class ShopItemDef {
  const ShopItemDef(this.id, this.row, this.fx, this.perLevel, this.maxLevel, this.costBase, this.costGrowth);

  final String id;
  final int row;
  final ShopFx fx;
  final double perLevel;
  final int maxLevel;
  final double costBase;
  final double costGrowth;

  int costAt(int level) => (costBase * math.pow(costGrowth, level)).ceil();
}

const shopDefs = [
  ShopItemDef('startParts', 1, ShopFx.levels, 5, 10, 3, 1.35),
  ShopItemDef('discount', 1, ShopFx.down, 4, 10, 4, 1.4),
  ShopItemDef('bossTime', 1, ShopFx.sec, 3, 5, 6, 1.5),
  ShopItemDef('offline', 2, ShopFx.hour, 1, 4, 10, 1.8),
  ShopItemDef('critChance', 2, ShopFx.pp, 1, 10, 5, 1.4),
  ShopItemDef('critDamage', 2, ShopFx.plus, 0.1, 10, 5, 1.4),
  ShopItemDef('fleetSlot', 3, ShopFx.slots, 1, 2, 60, 4),
  ShopItemDef('pieceGain', 3, ShopFx.percent, 10, 10, 8, 1.5),
  ShopItemDef('fastSail', 3, ShopFx.percent, 5, 4, 12, 1.6),
];

/// 줄이 열리는 '상점에 쓴 조각 누계' (1줄 0 · 2줄 30 · 3줄 150).
const shopRowUnlockAt = [0, 30, 150];

/// 상점 칸 하나 (경제 `RebirthShopView` 항목과 같은 모양).
@immutable
class ShopItemVm {
  const ShopItemVm({
    required this.def,
    required this.level,
    required this.cost,
    required this.unlocked,
    required this.affordable,
  });

  final ShopItemDef def;
  final int level;

  /// 다음 레벨 비용 (최대 레벨이면 null).
  final int? cost;
  final bool unlocked;
  final bool affordable;

  String get id => def.id;
  bool get maxed => level >= def.maxLevel;
  double get effectNow => def.perLevel * level;
  double get effectNext => def.perLevel * (level + 1);

  @override
  bool operator ==(Object other) =>
      other is ShopItemVm &&
      other.def.id == def.id &&
      other.level == level &&
      other.cost == cost &&
      other.unlocked == unlocked &&
      other.affordable == affordable;

  @override
  int get hashCode => Object.hash(def.id, level, cost, unlocked, affordable);
}

/// 상점 화면 전체.
@immutable
class ShopVm {
  const ShopVm({required this.items, required this.pieces, required this.spentTotal});

  final List<ShopItemVm> items;

  /// 쓸 수 있는 조각.
  final int pieces;

  /// 상점에 쓴 조각 누계 (줄 해금 기준).
  final int spentTotal;

  bool get anyAffordable => items.any((i) => i.affordable);

  /// [row]줄(1부터)이 열리려면 더 써야 하는 조각 (열렸으면 0).
  int toUnlock(int row) => math.max(0, shopRowUnlockAt[row - 1] - spentTotal);

  @override
  bool operator ==(Object other) =>
      other is ShopVm && other.pieces == pieces && other.spentTotal == spentTotal && _listEq(other.items, items);

  @override
  int get hashCode => Object.hash(pieces, spentTotal, Object.hashAll(items));
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 환생 버튼 미리보기 (경제 `rebirthForecast`).
typedef ForecastVm = ({double powerMultiplier, int minutesToBeat, int targetStage});

/// 환생 상자 내용 (`RebirthDone` += gems, summons, title?, skin?).
typedef ChestVm = ({int gems, int summons, String? title, String? skin});

/// 배 스킨 (스펙 2-2 표). 선체·돛·깃발은 미리보기 색 — 렌더 그림 함수가 오면 그것으로 바꾼다.
class SkinDef {
  const SkinDef(this.id, this.rebirths, this.hull, this.sail, this.flag);

  final String id;
  final int rebirths;
  final Color hull;
  final Color sail;
  final Color flag;
}

const skinDefs = [
  SkinDef('coral', 1, Color(0xFFFF8A8A), Color(0xFFFFF4F2), Color(0xFFFF5A9A)),
  SkinDef('storm', 3, Color(0xFF2C3E73), Color(0xFFB8C2D4), Color(0xFFFFD447)),
  SkinDef('gold', 5, Color(0xFFE0A21C), Color(0xFFFFF1CC), Color(0xFF6A3C00)),
  SkinDef('phantom', 10, Color(0xFF3FC9BE), Color(0xFFCFF7F2), Color(0xFF1C2A3A)),
];

/// 칭호 (스펙 3-1 표).
const titleDefs = [('deckhand', 1), ('navigator', 3), ('captain', 5), ('admiral', 10), ('seaKing', 20)];

/// 보물 바다 해역별 (적 체력 배수, 조각 배수)와 열리는 환생 횟수 (스펙 4-1 안 A).
const List<({double hp, double pieces, int rebirths})> treasureSeas = [
  (hp: 2.0, pieces: 1.5, rebirths: 3),
  (hp: 3.5, pieces: 2.0, rebirths: 5),
  (hp: 6.0, pieces: 3.0, rebirths: 8),
];

/// 이 화면이 직접 고르는 값 (계약 전 가짜 — 앱을 다시 켜면 사라진다).
@immutable
class RebirthV2Local {
  const RebirthV2Local({
    this.levels = const {},
    this.spent = 0,
    this.skin,
    this.skinPicked = false,
    this.title,
    this.sea,
  });

  final Map<String, int> levels;
  final int spent;
  final String? skin;

  /// 사용자가 스킨을 직접 고른 적이 있나 (있으면 새 스킨을 자동 장착하지 않는다).
  final bool skinPicked;
  final String? title;

  /// 다음 환생에 쓸 보물 바다 해역 (null = 끔).
  final int? sea;

  RebirthV2Local copyWith({
    Map<String, int>? levels,
    int? spent,
    String? Function()? skin,
    bool? skinPicked,
    String? Function()? title,
    int? Function()? sea,
  }) => RebirthV2Local(
    levels: levels ?? this.levels,
    spent: spent ?? this.spent,
    skin: skin == null ? this.skin : skin(),
    skinPicked: skinPicked ?? this.skinPicked,
    title: title == null ? this.title : title(),
    sea: sea == null ? this.sea : sea(),
  );
}

/// 환생 v2 명령 창구. 지금은 가짜(로컬 상태), 계약이 오면 `BuyRebirthUpgrade`·`SelectShipSkin`·`SelectTitle`·`SetTreasureRoute`를 보낸다.
final rebirthV2Provider = NotifierProvider<RebirthV2Controller, RebirthV2Local>(RebirthV2Controller.new);

class RebirthV2Controller extends Notifier<RebirthV2Local> {
  @override
  RebirthV2Local build() => const RebirthV2Local();

  /// 칸 하나 구매 — 조각 부족·상한·잠긴 줄이면 아무것도 하지 않는다(스펙 6장 거부 규칙).
  bool buy(String id) {
    // 상점 보기는 이 컨트롤러를 구독하므로 여기서 읽지 않고 같은 계산을 다시 한다(순환 의존 금지).
    final item = shopVmFor(state, ref.read(gameStateProvider).wallet.mapPieces).items.firstWhere((i) => i.id == id);
    if (!item.affordable) return false;
    state = state.copyWith(levels: {...state.levels, id: item.level + 1}, spent: state.spent + item.cost!);
    return true;
  }

  void selectSkin(String? id) => state = state.copyWith(skin: () => id, skinPicked: true);

  void selectTitle(String? id) => state = state.copyWith(title: () => id);

  void setTreasureRoute(int? sea) => state = state.copyWith(sea: () => sea);
}

/// 상점 보기 (경제 `shopView` 자리).
final rebirthShopProvider = Provider<ShopVm>(
  (ref) => shopVmFor(ref.watch(rebirthV2Provider), ref.watch(gameStateProvider.select((s) => s.wallet.mapPieces))),
);

/// 가짜 상태 + 보유 조각 → 상점 보기.
ShopVm shopVmFor(RebirthV2Local local, int owned) {
  final pieces = math.max(0, owned - local.spent);
  return ShopVm(
    pieces: pieces,
    spentTotal: local.spent,
    items: [
      for (final d in shopDefs)
        () {
          final level = local.levels[d.id] ?? 0;
          final cost = level >= d.maxLevel ? null : d.costAt(level);
          final unlocked = local.spent >= shopRowUnlockAt[d.row - 1];
          return ShopItemVm(
            def: d,
            level: level,
            cost: cost,
            unlocked: unlocked,
            affordable: unlocked && cost != null && cost <= pieces,
          );
        }(),
    ],
  );
}

/// 환생 미리보기 (경제 `rebirthForecast` 자리 — 가짜 근사). 잠겨 있으면 null.
final rebirthForecastProvider = Provider<ForecastVm? Function(int stage, int gain, int earned)>((ref) {
  return (stage, gain, earned) {
    if (stage < 40) return null;
    final mult = (1 + (earned + gain) * 0.05) / (1 + earned * 0.05);
    final minutes = ((stage / 4) / 5).ceil() * 5;
    return (powerMultiplier: mult, minutesToBeat: minutes, targetStage: stage);
  };
});

/// [rebirths]번째 환생 상자 (스펙 3-1 식). 계약이 오면 `RebirthDone` 필드를 그대로 쓴다.
ChestVm chestFor(int rebirths) => (
  gems: math.min(150, 50 + 10 * (rebirths - 1)),
  summons: rebirths >= 10 ? 3 : (rebirths >= 5 ? 2 : 1),
  title: titleDefs.where((t) => t.$2 == rebirths).map((t) => t.$1).firstOrNull,
  skin: skinDefs.where((s) => s.rebirths == rebirths).map((s) => s.id).firstOrNull,
);

/// 스킨 보기: 갖고 있는 스킨, 장착(고른 적 없으면 가장 먼저 얻은 것).
final shipSkinProvider = Provider<({Set<String> owned, String? equipped})>((ref) {
  final local = ref.watch(rebirthV2Provider);
  final rebirths = ref.watch(gameStateProvider.select((s) => s.progress.rebirths));
  final owned = {
    for (final s in skinDefs)
      if (rebirths >= s.rebirths) s.id,
  };
  final equipped = local.skinPicked ? local.skin : (owned.isEmpty ? null : skinDefs.first.id);
  return (owned: owned, equipped: equipped);
});

/// 칭호 보기: 가진 칭호, 고른 칭호.
final titleProvider = Provider<({Set<String> owned, String? selected})>((ref) {
  final local = ref.watch(rebirthV2Provider);
  final rebirths = ref.watch(gameStateProvider.select((s) => s.progress.rebirths));
  final owned = {
    for (final (id, n) in titleDefs)
      if (rebirths >= n) id,
  };
  return (owned: owned, selected: owned.contains(local.title) ? local.title : null);
});

/// 고를 수 있는 보물 바다 해역 수 (0이면 토글을 숨긴다).
final treasureSeaCountProvider = Provider<int>((ref) {
  final rebirths = ref.watch(gameStateProvider.select((s) => s.progress.rebirths));
  return treasureSeas.where((t) => rebirths >= t.rebirths).length;
});

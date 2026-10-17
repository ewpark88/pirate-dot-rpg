import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 환생 v2 화면용 보기 모델 (스펙 platform-rebirth-v2 7장). 경제 계약(S2 — shopView·BuyRebirthUpgrade·스킨·칭호·항로)을
// 화면이 쓰기 좋은 모양으로 옮긴다. 아직 없는 것은 rebirthForecast 하나(가짜 근사, 아래 표시).

/// 상점 효과 표시 단위 — 숫자 옆에 붙는 꼴(ARB `uiShopFx*`).
enum ShopFx { levels, down, sec, hour, pp, plus, slots, percent }

/// 상점 항목 id → (표시 단위, 경제 값 → 표시 숫자). 경제 값은 perLevel 단위 그대로(비율 0.04, 오프라인 초).
(ShopFx, double) shopDisplay(String id, double v) => switch (id) {
  'startParts' => (ShopFx.levels, v),
  'discount' => (ShopFx.down, v * 100),
  'bossTime' => (ShopFx.down, v * 100), // 철갑판: 보스전 배 피해 −% (2026-10-17, 보스 시간 제한 없음)
  'offline' => (ShopFx.hour, v / Duration.secondsPerHour),
  'critChance' => (ShopFx.pp, v * 100),
  'critDamage' => (ShopFx.plus, v),
  'fleetSlot' => (ShopFx.slots, v),
  _ => (ShopFx.percent, v * 100),
};

/// 상점 칸 하나 (경제 `ShopItemView`에서 화면에 쓰는 값만, == 있음 — 20Hz 상태에서 바뀔 때만 다시 그린다).
@immutable
class ShopItemVm {
  const ShopItemVm({
    required this.id,
    required this.row,
    required this.level,
    required this.maxLevel,
    required this.cost,
    required this.unlocked,
    required this.affordable,
    required this.effectNow,
    required this.effectNext,
    this.minorNow,
    this.minorNext,
  });

  factory ShopItemVm.of(ShopItemView v) => ShopItemVm(
    id: v.id,
    row: v.row,
    level: v.level,
    maxLevel: v.maxLevel,
    cost: v.cost,
    unlocked: v.unlocked,
    affordable: v.affordable,
    effectNow: v.effectNow,
    effectNext: v.effectNext,
    minorNow: v.effectNowMinor,
    minorNext: v.effectNextMinor,
  );

  final String id;
  final int row;
  final int level;
  final int maxLevel;

  /// 다음 레벨 비용 (최대 레벨이면 null).
  final int? cost;
  final bool unlocked;
  final bool affordable;
  final double effectNow;

  /// 다음 레벨 효과 (최대 레벨이면 null).
  final double? effectNext;

  /// 두 번째 값 (startParts: 돛·망루 시작 레벨). 없으면 null.
  final double? minorNow;
  final double? minorNext;

  bool get maxed => level >= maxLevel;

  @override
  bool operator ==(Object other) =>
      other is ShopItemVm &&
      other.id == id &&
      other.level == level &&
      other.cost == cost &&
      other.unlocked == unlocked &&
      other.affordable == affordable;

  @override
  int get hashCode => Object.hash(id, level, cost, unlocked, affordable);
}

/// 상점 화면 전체.
@immutable
class ShopVm {
  const ShopVm({required this.items, required this.pieces, required this.spentTotal, required this.rows});

  final List<ShopItemVm> items;

  /// 쓸 수 있는 조각.
  final int pieces;

  /// 상점에 쓴 조각 누계 (줄 해금 기준).
  final int spentTotal;

  /// 줄마다 열리는 쓴 누계 (meta.rebirth.shopRows).
  final List<int> rows;

  bool get anyAffordable => items.any((i) => i.affordable);

  /// [row]줄(1부터)이 열리려면 더 써야 하는 조각 (열렸으면 0).
  int toUnlock(int row) => math.max(0, rows[row - 1] - spentTotal);

  /// [row]줄이 열리는 쓴 누계.
  int unlockAt(int row) => rows[row - 1];

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

List<int> _rows(GameTables t) => [for (final r in t.meta.rebirth.raw['shopRows'] as List) (r as num).toInt()];

/// 환생 버튼 미리보기 (경제 `rebirthForecast`).
typedef ForecastVm = ({double powerMultiplier, int minutesToBeat, int targetStage});

/// 환생 상자 내용 (`RebirthDone` += gems, summons, title?, skin?).
typedef ChestVm = ({int gems, int summons, String? title, String? skin});

/// 배 스킨 (meta.rebirth.skins와 같은 id·회차 — 테스트가 맞춘다). 선체·돛·깃발은 미리보기 색 — 렌더 그림 함수가 오면 그것으로 바꾼다.
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

/// 칭호 (meta.rebirth.titles와 같은 id·회차 — 테스트가 맞춘다).
const titleDefs = [('deckhand', 1), ('navigator', 3), ('captain', 5), ('admiral', 10), ('seaKing', 20)];

/// 환생 v2 명령 창구 (경제 명령을 보낸다 — 결과는 상태로 돌아온다).
final rebirthV2Provider = Provider<RebirthV2Commands>(RebirthV2Commands.new);

class RebirthV2Commands {
  RebirthV2Commands(this._ref);

  final Ref _ref;

  void _send(Command c) => _ref.read(commandSinkProvider).send(c);

  /// 칸 하나 구매 — 살 수 없으면(조각 부족·상한·잠긴 줄) 보내지 않는다. 보냈으면 true.
  bool buy(String id) {
    final item = _ref.read(rebirthShopProvider).items.where((i) => i.id == id).firstOrNull;
    if (item == null || !item.affordable) return false;
    _send(BuyRebirthUpgrade(id));
    return true;
  }

  void selectSkin(String? id) => _send(SelectShipSkin(id));

  void selectTitle(String? id) => _send(SelectTitle(id));

  void setTreasureRoute(int? sea) => _send(SetTreasureRoute(sea));
}

/// 상점 보기 (경제 `shopView`).
final rebirthShopProvider = Provider<ShopVm>((ref) {
  final t = ref.watch(tablesProvider);
  final rows = _rows(t);
  return ref.watch(
    gameStateProvider.select((s) {
      final v = shopView(s, t);
      return ShopVm(
        items: [for (final i in v.items) ShopItemVm.of(i)],
        pieces: s.wallet.mapPieces,
        spentTotal: v.spentTotal,
        rows: rows,
      );
    }),
  );
});

/// 보물 바다 해역별 (적 체력 배수, 조각 배수) — meta.rebirth.treasureSeas.
final treasureSeasProvider = Provider<List<({double hp, double pieces})>>((ref) {
  final t = ref.watch(tablesProvider);
  return [
    for (final o in t.meta.rebirth.objs('treasureSeas'))
      (hp: o.number('hpMultiplier'), pieces: o.number('piecesMultiplier')),
  ];
});

/// 다음 환생에 쓸 보물 바다 해역 (null = 끔, 경제 progress.treasureRoute).
final treasureRouteProvider = Provider<int?>(
  (ref) => ref.watch(gameStateProvider.select((s) => s.progress.treasureRoute)),
);

/// 환생 미리보기 (경제 `rebirthForecast`). 잠겨 있으면 null. 카드가 다시 그려질 때(스테이지·조각이 바뀔 때)만 부른다.
final rebirthForecastProvider = Provider<ForecastVm? Function(GameState state)>((ref) {
  final t = ref.watch(tablesProvider);
  return (s) {
    final f = rebirthForecast(s, t);
    return f == null
        ? null
        : (powerMultiplier: f.powerMultiplier, minutesToBeat: f.minutesToBeat, targetStage: f.targetStage);
  };
});

/// [rebirths]번째 환생 상자 (스펙 3-1 식) — 확인 창 미리보기용. 실제 팝업은 `RebirthDone` 필드를 쓴다.
ChestVm chestFor(int rebirths) => (
  gems: math.min(150, 50 + 10 * (rebirths - 1)),
  summons: rebirths >= 10 ? 3 : (rebirths >= 5 ? 2 : 1),
  title: titleDefs.where((t) => t.$2 == rebirths).map((t) => t.$1).firstOrNull,
  skin: skinDefs.where((s) => s.rebirths == rebirths).map((s) => s.id).firstOrNull,
);

/// 스킨 보기: 갖고 있는 스킨, 장착 (경제 ship.skinsOwned · ship.skin).
final shipSkinProvider = Provider<({Set<String> owned, String? equipped})>((ref) {
  final (owned, equipped) = ref.watch(gameStateProvider.select((s) => (s.ship.skinsOwned.join(','), s.ship.skin)));
  return (owned: owned.isEmpty ? <String>{} : owned.split(',').toSet(), equipped: equipped);
});

/// 칭호 보기: 가진 칭호, 고른 칭호 (경제 progress.titles · settings.title).
final titleProvider = Provider<({Set<String> owned, String? selected})>((ref) {
  final (owned, selected) = ref.watch(gameStateProvider.select((s) => (s.progress.titles.join(','), s.settings.title)));
  final set = owned.isEmpty ? <String>{} : owned.split(',').toSet();
  return (owned: set, selected: set.contains(selected) ? selected : null);
});

/// 고를 수 있는 보물 바다 해역 수 (0이면 토글을 숨긴다, 경제 treasureSeasUnlocked).
final treasureSeaCountProvider = Provider<int>((ref) {
  final t = ref.watch(tablesProvider);
  return ref.watch(gameStateProvider.select((s) => treasureSeasUnlocked(s, t)));
});

/// 환생 상자 팝업이 떠 있나 — 상자의 영웅 소환 결과 창은 상자를 닫은 뒤에 연다(상자 → 소환 → 항해 순서).
final rebirthChestOpenProvider = NotifierProvider<RebirthChestOpen, bool>(RebirthChestOpen.new);

class RebirthChestOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void opened() => state = true;

  void closed() => state = false;
}

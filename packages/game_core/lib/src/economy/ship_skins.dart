import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

// 배 스킨 얻는 길 (docs/specs/economy-ship-skins.md, S1 결정 2026-10-17 — 꾸밈만, 능력치 없음).
// 환생 스킨 4종은 meta.rebirth.skins 그대로. 나머지는 meta.shipSkins [{id, nameKey, source: {type, value}}]:
// collection(보유 선원 수) · bestStage(최고 스테이지) · bountyTier(아무 현상금 보스 단계) · bountyAll(모든 현상금 보스 단계) — 닿으면 자동,
// pieces(보물지도 조각으로 사기, BuySkin). 해금은 skinsOwned + SkinUnlocked(환생 스킨과 같은 길), 옛 세이브는 첫 틱에 소급.

/// 스킨 한 칸 (UI 목록·진행): 지금 값 `now` / 목표 `value`.
typedef ShipSkinView = ({String id, String nameKey, String type, int value, int now, bool owned});

int _now(GameState s, GameTables t, JsonReader src) {
  final cleared = s.bounty?.cleared ?? const <String, int>{};
  return switch (src.str('type')) {
    'collection' => s.collection.length,
    'bestStage' => s.progress.bestStage,
    'bountyTier' => cleared.values.fold(0, (a, b) => a > b ? a : b),
    'bountyAll' => [
      for (final d in t.meta.raw.obj('bounty').objs('days')) cleared[d.str('boss')] ?? 0,
    ].reduce((a, b) => a < b ? a : b), // 가장 낮은 보스의 단계
    'pieces' => s.wallet.mapPieces,
    _ => 0,
  };
}

List<ShipSkinView> shipSkinsView(GameState s, GameTables t) => [
  for (final k in t.meta.raw.objs('shipSkins'))
    (
      id: k.str('id'),
      nameKey: k.str('nameKey'),
      type: k.obj('source').str('type'),
      value: k.obj('source').integer('value'),
      now: _now(s, t, k.obj('source')),
      owned: s.ship.skinsOwned.contains(k.str('id')),
    ),
];

/// 매 틱(EconomySystem.update): 자동 길(조각 말고)의 조건에 닿은 스킨을 연다. 바뀐 게 없으면 같은 상태.
GameState unlockShipSkins(GameState s, SystemContext ctx) {
  final t = ctx.tables;
  if (!t.meta.raw.has('shipSkins')) return s;
  final fresh = [
    for (final v in shipSkinsView(s, t))
      if (!v.owned && v.type != 'pieces' && v.now >= v.value) v.id,
  ];
  if (fresh.isEmpty) return s;
  for (final id in fresh) {
    ctx.emit(SkinUnlocked(ctx.tick, id: id));
  }
  return s.copyWith(ship: s.ship.copyWith(skinsOwned: {...s.ship.skinsOwned, ...fresh}));
}

/// BuySkin: 조각 스킨을 조각 value개로 산다. 조각이 모자라거나 이미 있거나 조각 스킨이 아니면 그대로.
GameState buySkin(GameState s, BuySkin c, SystemContext ctx) {
  final v = shipSkinsView(s, ctx.tables).where((x) => x.id == c.id).firstOrNull;
  if (v == null || v.owned || v.type != 'pieces' || s.wallet.mapPieces < v.value) return s;
  ctx
    ..emit(SkinUnlocked(ctx.tick, id: v.id))
    ..emit(SaveRequested(ctx.tick, reason: c.type));
  return s.copyWith(
    wallet: s.wallet.copyWith(mapPieces: s.wallet.mapPieces - v.value),
    ship: s.ship.copyWith(skinsOwned: {...s.ship.skinsOwned, v.id}),
  );
}

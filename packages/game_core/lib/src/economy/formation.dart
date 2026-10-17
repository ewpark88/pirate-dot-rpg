import 'dart:math' as math;

import 'package:game_core/src/battle/fleet.dart';
import 'package:game_core/src/economy/rebirth_shop.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

export 'package:game_core/src/battle/fleet.dart' show autoFleet;

// 수동 편성 (사용자 결정 2026-10-15, ADR-0010): 출전은 사용자가 고르고, ‘자동 편성’ 버튼으로 한 번에 채운다.

/// 출전 슬롯 수 — 한 번 연 칸은 영구(평생 최고 스테이지의 배 등급 기준, 사용자 버그 2026-10-17 '환생하니 4번째 칸이 다시 잠김').
/// bestStage는 환생해도 유지된다. 한 번이라도 환생했으면 환생 조건 스테이지(meta.rebirth.minStage)까지는 간 것이니
/// 그 등급 칸이 바닥(폰 재현 2026-10-17 — 세이브의 bestStage가 어긋나도 칸이 다시 잠기지 않게).
int fleetSlots(GameState s, GameTables t) {
  final p = s.progress;
  final reached = p.rebirths > 0 ? math.max(p.bestStage, t.meta.rebirth.integer('minStage')) : p.bestStage;
  final n = t.shipTiers.tierAt(reached).slots + fleetSlotBonus(s, t);
  final max = t.meta.rebirth.integer('fleetSlotsMax');
  return n > max ? max : n;
}

/// 실제로 출전하는 선원 (슬롯 순서, 빈 칸·미보유 제외). 전투·오프라인·상자 추정이 모두 이것을 쓴다.
/// 편성한 적이 없으면(첫 틱 전) 자동 편성과 같다.
List<String> activeFleet(GameState s, GameTables t) {
  final slots = fleetSlots(s, t);
  if (!s.fleetInit) return autoFleet(s, t, slots);
  return [
    for (final id in s.fleet.take(slots))
      if (id != null && s.crews.containsKey(id)) id,
  ];
}

/// 출전 탭 배지: 쉬는 보유 선원이 있을 때 채울 수 있는 빈 칸 수. 없으면 0.
int emptySlotCount(GameState s, GameTables t) {
  final active = activeFleet(s, t);
  final empty = fleetSlots(s, t) - active.length;
  final bench = s.crews.length - active.length;
  return empty <= 0 || bench <= 0 ? 0 : (empty < bench ? empty : bench);
}

/// 편성한 적이 없으면 자동 편성으로 채운다 (새 게임·v4 이전 세이브의 첫 틱).
GameState ensureFleet(GameState s, GameTables t) =>
    s.fleetInit ? s : s.copyWith(fleet: autoFleet(s, t, fleetSlots(s, t)), fleetInit: true);

GameState onAutoFleet(GameState s, AutoFleet c, SystemContext ctx) {
  final next = autoFleet(s, ctx.tables, fleetSlots(s, ctx.tables));
  ctx.emit(SaveRequested(ctx.tick, reason: c.type));
  return s.copyWith(fleet: next, fleetInit: true);
}

GameState setFleetSlot(GameState state, SetFleetSlot c, SystemContext ctx) {
  final t = ctx.tables;
  final s = ensureFleet(state, t);
  final id = c.crewId;
  if (c.slot < 0 || c.slot >= fleetSlots(s, t) || (id != null && !s.crews.containsKey(id))) return state;
  final fleet = [...s.fleet];
  while (fleet.length <= c.slot) {
    fleet.add(null);
  }
  // 마지막 출전 선원은 내릴 수 없다(S4 요청 — 오래된 클라이언트·운영자 경로로도 0명이 되지 않게).
  if (id == null && c.slot < fleet.length && fleet[c.slot] != null && activeFleet(s, t).length <= 1) {
    ctx.emit(FleetRejected(ctx.tick, slot: c.slot, crewId: fleet[c.slot]!, reason: 'last'));
    return state;
  }
  final from = id == null ? -1 : fleet.indexOf(id);
  if (id != null && from < 0 && _overFamilyCap(s, t, fleet, c.slot, id)) {
    ctx.emit(FleetRejected(ctx.tick, slot: c.slot, crewId: id, reason: 'family'));
    return state;
  }
  if (from >= 0) fleet[from] = fleet[c.slot];
  fleet[c.slot] = id;
  ctx.emit(SaveRequested(ctx.tick, reason: c.type));
  return s.copyWith(fleet: fleet, fleetInit: true);
}

/// [slot]의 선원을 [id]로 바꾸면 출전 칸 안의 같은 계열이 상한을 넘는가.
bool _overFamilyCap(GameState s, GameTables t, List<String?> fleet, int slot, String id) {
  final family = t.crews.byId(id).family;
  var n = 1;
  final slots = fleetSlots(s, t);
  for (var i = 0; i < slots && i < fleet.length; i++) {
    final other = fleet[i];
    if (i != slot && other != null && t.crews.byId(other).family == family) n++;
  }
  return n > t.skills.maxSameFamilyInFleet;
}

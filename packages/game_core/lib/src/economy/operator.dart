import 'dart:math' as math;

import 'package:game_core/src/economy/cards.dart';
import 'package:game_core/src/economy/crew_stats.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';

// 경제 운영자 명령 (설계서 6.10). 엔진이 operator 표시를 이미 붙인 뒤 들어온다.

/// 선원 레벨 지정(1~maxLevel). 미보유면 보유 + 도감. 모르는 선원은 무시.
GameState opSetCrew(GameState state, OpSetCrew c, SystemContext ctx) {
  final t = ctx.tables;
  if (!t.crews.crews.any((d) => d.id == c.crewId)) return state;
  final level = math.min(math.max(c.level, 1), t.growth.maxLevel);
  final crew = state.crews[c.crewId] ?? const CrewState();
  return state.copyWith(
    crews: {
      ...state.crews,
      c.crewId: crew.copyWith(level: level, exp: 0),
    },
    collection: {...state.collection, c.crewId},
  );
}

/// 재화 지급. 카드는 선원의 현재 등급(미보유면 가장 낮은 등급)으로 카드 받기 규칙을 탄다.
GameState opGrant(GameState state, OpGrant c, SystemContext ctx) {
  final t = ctx.tables;
  final w = state.wallet;
  var s = state.copyWith(
    wallet: w.copyWith(gold: c.gold == null ? null : w.gold + c.gold!, gems: w.gems + c.gems),
    tokens: state.tokens + c.tokens,
  );
  for (final e in c.cards.entries) {
    if (!t.crews.crews.any((d) => d.id == e.key)) continue;
    for (var i = 0; i < e.value; i++) {
      final crew = s.crews[e.key];
      final rarity = crew == null ? t.rarities.rarities.first.id : rarityOfLevel(t.rarities, crew.level).id;
      s = receiveCard(s, t, e.key, rarity);
    }
  }
  return s;
}

/// 배 부위 레벨 지정. 아는 부위만, 0~maxLevel로 자른다.
GameState opSetShip(GameState state, OpSetShip c, SystemContext ctx) {
  var ship = state.ship;
  for (final p in ctx.tables.shipParts.parts) {
    final level = c.parts[p.id];
    if (level == null) continue;
    final max = p.maxLevel;
    ship = ship.withLevel(p.id, math.max(0, max == null ? level : math.min(level, max)));
  }
  return state.copyWith(ship: ship);
}

/// 가짜 시간 경과: 시계는 포트라 건드리지 않고, 마지막 저장 시각을 [OpAdvanceClock.by]만큼 과거로 옮긴다.
/// 다음 ClaimOffline이 그 시간을 보상한다.
GameState opAdvanceClock(GameState state, OpAdvanceClock c, SystemContext ctx) =>
    state.copyWith(savedAt: state.savedAt.subtract(c.by));

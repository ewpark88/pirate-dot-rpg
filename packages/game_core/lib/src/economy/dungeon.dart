import 'dart:math' as math;

import 'package:game_core/src/battle/combat_stats.dart' show crewPower;
import 'package:game_core/src/economy/cards.dart' show grantCard;
import 'package:game_core/src/economy/formation.dart' show fleetSlots;
import 'package:game_core/src/economy/rush.dart' show sceneBusy;
import 'package:game_core/src/economy/tower.dart' show towerOpen;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_data/game_data.dart';

// 요일 던전 — 경제 (docs/specs/platform-weekday-dungeon.md — S1 승인 2026-10-18). 요일 묶음·출전 선원·도전 충전·시작·소탕·보상.
// 전투(top_dungeon.dart)는 dungeon.active를 보고 장면을 열고(출전은 전장에서만 임시 교체), 클리어 때 [dungeonReward]를 부른다.

JsonReader dungeonCfg(GameTables t) => t.meta.raw.obj('dungeon');

/// 요일(1 월 ~ 7 일)의 묶음. 운영자 요일 고정(현상금 OpSetWeekday)이 있으면 그것.
JsonReader dungeonGroupOn(GameTables t, int weekday) =>
    dungeonCfg(t).objs('groups').firstWhere((g) => g.integer('weekday') == weekday);

JsonReader dungeonGroupById(GameTables t, String id) =>
    dungeonCfg(t).objs('groups').firstWhere((g) => g.str('id') == id);

/// 오늘 묶음(현지 요일, 운영자 고정 요일 우선).
JsonReader dungeonToday(GameState s, GameTables t, DateTime now) => dungeonGroupOn(t, s.bounty?.weekday ?? now.weekday);

/// 그 묶음에 출전할 선원: 보유 중 묶음 계열(비면 모든 계열)인 선원을 파워 순으로 출전 칸 수만큼.
List<String> dungeonCrews(GameState s, GameTables t, JsonReader group) {
  final families = group.strs('families');
  final owned = [
    for (final c in t.crews.crews)
      if (s.crews[c.id] case final st? when families.isEmpty || families.contains(c.family))
        (id: c.id, power: crewPower(t, st.level)),
  ]..sort((a, b) => b.power.compareTo(a.power));
  return [for (final c in owned.take(fleetSlots(s, t))) c.id];
}

/// 매 틱: 열렸는데 상태가 없으면 도전 ticketsPerDay로 만든다. 날짜가 바뀐 첫 틱엔 지난 일수만큼 maxTickets까지 더한다(탑과 같음).
GameState dungeonTick(GameState s, SystemContext ctx) {
  final t = ctx.tables;
  final today = localDate(ctx.clock.now());
  final d = s.dungeon;
  final c = dungeonCfg(t);
  if (d == null) {
    if (!towerOpen(s, t)) return s;
    return s.copyWith(
      dungeon: DungeonState(tickets: c.integer('ticketsPerDay'), refilledOn: today),
    );
  }
  if (d.refilledOn == today) return s;
  final last = d.refilledOn == null ? null : DateTime.tryParse(d.refilledOn!);
  final days = last == null ? 0 : DateTime.parse(today).difference(last).inDays;
  final room = math.max(0, c.integer('maxTickets') - d.tickets);
  final add = math.min(room, math.max(0, days) * c.integer('ticketsPerDay'));
  return s.copyWith(
    dungeon: d.copyWith(tickets: d.tickets + add, refilledOn: today),
  );
}

/// 지금 [step] 단계에 들어갈 수 있나: 열림·도전 ≥ 1·장면 모드 아님·그 날 선원 보유·1 ≤ step ≤ min(깬 단계 + 1, steps).
bool canStartDungeon(GameState s, GameTables t, DateTime now, int step) {
  final d = s.dungeon;
  if (!towerOpen(s, t) || d == null || d.tickets < 1 || sceneBusy(s)) return false;
  final g = dungeonToday(s, t, now);
  if (dungeonCrews(s, t, g).isEmpty) return false;
  final open = math.min((d.cleared[g.str('id')] ?? 0) + 1, dungeonCfg(t).integer('steps'));
  return step >= 1 && step <= open;
}

GameState startDungeon(GameState s, StartDungeon c, SystemContext ctx) {
  final now = ctx.clock.now();
  if (!canStartDungeon(s, ctx.tables, now, c.step)) return s;
  final d = s.dungeon!;
  final g = dungeonToday(s, ctx.tables, now).str('id');
  return s.copyWith(
    dungeon: d.copyWith(
      tickets: d.tickets - 1,
      active: DungeonActive(group: g, step: c.step),
    ),
  );
}

/// 소탕: 오늘 묶음에서 깬 단계 [SweepDungeon.step] 이하의 보상을 바로. 도전 −1.
GameState sweepDungeon(GameState s, SweepDungeon c, SystemContext ctx) {
  final d = s.dungeon;
  if (d == null || d.tickets < 1 || sceneBusy(s) || c.step < 1) return s;
  final g = dungeonToday(s, ctx.tables, ctx.clock.now());
  if (c.step > (d.cleared[g.str('id')] ?? 0)) return s;
  final paid = dungeonReward(s.copyWith(dungeon: d.copyWith(tickets: d.tickets - 1)), ctx, g, c.step, swept: true);
  return paid;
}

/// 단계 [step] 보상: 묶음 계열 선원(보유) 카드 step × cardsPerStep장(장마다 결정론 추첨) + 젬 step × gemsPerStep. DungeonCleared를 낸다.
GameState dungeonReward(GameState s, SystemContext ctx, JsonReader group, int step, {bool swept = false}) {
  final t = ctx.tables;
  final c = dungeonCfg(t);
  final pool = dungeonCrews(s, t, group);
  final allOwned = pool.isEmpty ? (s.crews.keys.toList()..sort()) : pool;
  var next = s;
  final cards = <String>[];
  for (var i = 0; i < step * c.integer('cardsPerStep') && allOwned.isNotEmpty; i++) {
    final id = allOwned[ctx.rng.nextInt(allOwned.length)];
    cards.add(id);
    next = grantCard(next, ctx, id, t.crews.byId(id).baseRarity, 'dungeon');
  }
  final gems = step * c.integer('gemsPerStep');
  ctx.emit(DungeonCleared(ctx.tick, group: group.str('id'), step: step, cards: cards, gems: gems, swept: swept));
  return next.copyWith(wallet: next.wallet.copyWith(gems: next.wallet.gems + gems));
}

/// 광고 도전(AdPlacement.dungeonTicket): +value, 하루 1.
GameState dungeonAdTicket(GameState s, int value, DateTime now) {
  final d = s.dungeon;
  if (d == null) return s;
  return s.copyWith(
    dungeon: d.copyWith(tickets: d.tickets + value, adOn: localDate(now)),
  );
}

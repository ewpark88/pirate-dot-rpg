import 'dart:math' as math;

import 'package:game_core/src/economy/bounty.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_data/game_data.dart';

// 현상금 사냥 B2 — 경제 흐름 (docs/specs/platform-content-bounty.md 1·5절, 요청 platform-bounty-b0b2.md).
// 티켓 충전 · StartBounty(티켓 −1, active) · SweepBounty · 운영자 명령. 전투(B1, S5)는 active를 보고 전장을 연다.

JsonReader _cfg(GameTables t) => t.meta.raw.obj('bounty');

/// 첫 틱: 현상금 상태가 없으면 티켓 ticketsPerDay, 오늘 충전으로 만든다(옛 세이브 · 새 게임).
/// 날짜가 바뀐 첫 틱: 지난 일수 × ticketsPerDay를 ticketCap까지 더하고 BountyTicketsRefilled.
GameState bountyTick(GameState s, SystemContext ctx) {
  final t = ctx.tables;
  final today = localDate(ctx.clock.now());
  final b = s.bounty;
  if (b == null) {
    return s.copyWith(
      bounty: BountyState(tickets: _cfg(t).integer('ticketsPerDay'), refilledOn: today),
    );
  }
  if (b.refilledOn == today) return s;
  // 충전 기록이 없으면(옛 세이브 · 테스트 상태) 오늘로만 찍는다 — 지난 일수를 모르니 더하지 않는다.
  final last = b.refilledOn == null ? null : DateTime.tryParse(b.refilledOn!);
  if (last == null) return s.copyWith(bounty: b.copyWith(refilledOn: today));
  final days = DateTime.parse(today).difference(last).inDays;
  if (days <= 0) return s.copyWith(bounty: b.copyWith(refilledOn: today));
  final cap = _cfg(t).integer('ticketCap');
  final room = math.max(0, cap - b.tickets);
  final add = math.min(room, days * _cfg(t).integer('ticketsPerDay'));
  if (add > 0) ctx.emit(BountyTicketsRefilled(ctx.tick, count: add));
  return s.copyWith(
    bounty: b.copyWith(tickets: b.tickets + add, refilledOn: today),
  );
}

/// StartBounty: 오늘 보스·열린 단계·티켓이면 티켓 −1, active. 아니면 그대로(거절).
GameState startBounty(GameState s, StartBounty c, SystemContext ctx) {
  final b = s.bounty;
  if (b == null || !canStartBounty(s, ctx.tables, ctx.clock.now(), c.bossId, c.tier, weekday: b.weekday)) return s;
  ctx.emit(SaveRequested(ctx.tick, reason: c.type));
  return s.copyWith(
    bounty: b.copyWith(
      tickets: b.tickets - 1,
      active: BountyActive(bossId: c.bossId, tier: c.tier),
    ),
  );
}

/// SweepBounty: 깬 최고 단계로 count장(티켓이 모자라면 있는 만큼) 즉시 보상. 깬 단계가 없거나 현상금 중이면 무시.
GameState sweepBounty(GameState s, SweepBounty c, SystemContext ctx) {
  final t = ctx.tables;
  final b = s.bounty;
  final tier = b?.cleared[c.bossId] ?? 0;
  if (b == null || b.active != null || tier < 1 || c.count < 1 || b.tickets < 1) return s;
  final n = math.min(c.count, b.tickets);
  var next = s;
  var total = 0;
  String? crewId;
  var type = '';
  for (var i = 0; i < n; i++) {
    final r = bountyReward(next, t, c.bossId, tier, ctx.rng);
    next = grantBountyReward(next, ctx, r);
    total += r.amount;
    type = r.type;
    crewId ??= r.crewId;
  }
  ctx
    ..emit(
      BountySwept(
        ctx.tick,
        bossId: c.bossId,
        tier: tier,
        count: n,
        reward: BountyReward(type: type, amount: total, crewId: crewId),
      ),
    )
    ..emit(SaveRequested(ctx.tick, reason: c.type));
  return next.copyWith(bounty: next.bounty!.copyWith(tickets: next.bounty!.tickets - n));
}

GameState opSetBountyTickets(GameState s, OpSetBountyTickets c) =>
    s.copyWith(bounty: (s.bounty ?? const BountyState()).copyWith(tickets: math.max(0, c.count)));

/// 요일 고정(운영자). 세이브에 남지 않는다(BountyState.weekday는 toJson에서 빠진다).
GameState opSetWeekday(GameState s, OpSetWeekday c) => s.copyWith(
  bounty: (s.bounty ?? const BountyState()).copyWith(weekday: c.weekday, clearWeekday: c.weekday == null),
);

/// 현상금 중인가 — 돌발 이벤트·상자를 띄우지 않는다.
bool bountyActive(GameState s) => s.bounty?.active != null;

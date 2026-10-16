import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 현상금 B2 경제 흐름 (docs/specs/platform-content-bounty.md 8절 수용 기준 1~3·8).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  final cfg = t.meta.raw.obj('bounty');
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  GameState withBounty(BountyState b) => h.newGame().copyWith(
    bounty: b,
    crews: const {'octo': CrewState(level: 5), 'turtle': CrewState(level: 5)},
  );

  test('상태가 없으면 첫 틱에 ticketsPerDay, 오늘 충전', () {
    final s = sys.update(h.newGame(), h.ctx);
    expect(s.bounty!.tickets, cfg.integer('ticketsPerDay'));
    expect(s.bounty!.refilledOn, localDate(EconomyHarness.start));
  });

  test('기준 1: refilledOn 3일 전·티켓 2 → 티켓 상한까지, BountyTicketsRefilled(7)', () {
    final threeDaysAgo = localDate(EconomyHarness.start.subtract(const Duration(days: 3)));
    final s = sys.update(withBounty(BountyState(tickets: 2, refilledOn: threeDaysAgo)), h.ctx);
    expect(s.bounty!.tickets, cfg.integer('ticketCap'));
    expect(h.of<BountyTicketsRefilled>().single.count, cfg.integer('ticketCap') - 2);
  });

  test('기준 2: 요일이 다른 보스는 거절, 운영자 요일 고정이면 허용 — 요일 고정은 세이브에 남지 않는다', () {
    final today = EconomyHarness.start.weekday;
    final other = bountyBosses(t).firstWhere((id) => bountyBossOn(t, today) != id);
    final otherDay = [for (var d = 1; d <= 6; d++) d].firstWhere((d) => bountyBossOn(t, d) == other);
    final s0 = withBounty(BountyState(tickets: 2, refilledOn: localDate(EconomyHarness.start)));
    if (bountyBossOn(t, today) != anyBoss) {
      expect(sys.handle(s0, StartBounty(other, 1), h.ctx), same(s0));
    }
    final fixed = sys.handle(s0, OpSetWeekday(otherDay), h.ctx)!;
    final started = sys.handle(fixed, StartBounty(other, 1), h.ctx)!;
    expect(started.bounty!.tickets, 1);
    expect(started.bounty!.active!.bossId, other);
    expect(SaveCodec.decode(SaveCodec.encode(fixed)).bounty!.weekday, isNull);
  });

  test('기준 3: 깬 단계가 없으면 소탕 거절, 깼으면 count장(티켓만큼) 보상 + BountySwept', () {
    final boss = bountyBosses(t).first;
    final none = withBounty(const BountyState(tickets: 3));
    expect(sys.handle(none, SweepBounty(boss, 2), h.ctx), same(none));
    final cleared = withBounty(BountyState(tickets: 2, cleared: {boss: 3}));
    final s = sys.handle(cleared, SweepBounty(boss, 5), h.ctx)!;
    final e = h.of<BountySwept>().single;
    expect([e.count, e.tier, s.bounty!.tickets], [2, 3, 0]);
  });

  test('OpSetBountyTickets', () {
    expect(sys.handle(withBounty(const BountyState()), const OpSetBountyTickets(7), h.ctx)!.bounty!.tickets, 7);
  });
}

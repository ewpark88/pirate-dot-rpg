import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 스펙 economy-m1 수용 기준 1~4.
void main() {
  const sys = EconomySystem();
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());
  final cannon = EconomyHarness.tables.shipParts.byId('cannon');
  final m = cannon.milestoneEvery!;
  num cost(int lv) => cannon.costBase * math.pow(cannon.costGrowth, lv);

  test('기준 1: 대포 Lv0에서 3회 강화하면 Lv3, 비용 합만큼 골드가 줄고 PartUpgraded 3개', () {
    final s0 = h.newGame(gold: BigNum.from(1000));
    final s = sys.handle(s0, const UpgradePart('cannon', times: 3), h.ctx)!;
    expect(s.ship.level('cannon'), 3);
    expect(s.wallet.gold.closeTo(BigNum.from(1000 - cost(0) - cost(1) - cost(2))), isTrue);
    expect(h.of<PartUpgraded>().map((e) => e.level), [1, 2, 3]);
    expect(h.of<SaveRequested>(), hasLength(1));
  });

  test('기준 2: 대포 milestoneEvery − 1 → milestoneEvery에서 PartMilestone, 공격력 × milestoneMultiplier 도약', () {
    final s0 = h.newGame(gold: BigNum.parse('1e30')).copyWith(ship: const ShipState().withLevel('cannon', m - 1));
    final s = sys.handle(s0, const UpgradePart('cannon'), h.ctx)!;
    expect(s.ship.level('cannon'), m);
    expect(h.of<PartMilestone>().single.level, m);
    final t = EconomyHarness.tables.shipParts;
    final jump = shipAttack(t, m) / shipAttack(t, m - 1);
    expect(jump.toDouble(), closeTo(cannon.growth * cannon.milestoneMultiplier, 1e-9));
  });

  test('기준 3: 골드가 모자라면 상태·이벤트 변화 없음', () {
    final s0 = h.newGame(gold: BigNum.from(9));
    final s = sys.handle(s0, const UpgradePart('cannon'), h.ctx)!;
    expect(s.ship.level('cannon'), 0);
    expect(s.wallet.gold, BigNum.from(9));
    expect(h.events, isEmpty);
  });

  test('times만큼 못 사면 살 수 있는 만큼만 산다', () {
    // 2레벨 값보다 조금 많고 3레벨 값엔 모자란 골드.
    final s0 = h.newGame(gold: BigNum.from(cost(0) + cost(1) + cost(2) / 2));
    final s = sys.handle(s0, const UpgradePart('cannon', times: 10), h.ctx)!;
    expect(s.ship.level('cannon'), 2);
    expect(h.of<PartUpgraded>(), hasLength(2));
  });

  test('기준 4: 돛 Lv30(최대)은 더 오르지 않는다 · 망루 Lv45 치명타 50%', () {
    final s0 = h.newGame(gold: BigNum.from(1e30)).copyWith(ship: const ShipState().withLevel('sail', 30));
    final s = sys.handle(s0, const UpgradePart('sail'), h.ctx)!;
    expect(s.ship.level('sail'), 30);
    expect(h.events, isEmpty);
    expect(critChance(EconomyHarness.tables.shipParts, 45), closeTo(0.5, 1e-12));
  });

  test('모르는 부위는 무시', () {
    final s0 = h.newGame(gold: BigNum.from(1000));
    final s = sys.handle(s0, const UpgradePart('anchor'), h.ctx)!;
    expect(s.wallet.gold, BigNum.from(1000));
    expect(h.events, isEmpty);
  });
}

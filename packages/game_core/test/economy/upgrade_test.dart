import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_core/src/economy/ship_stats.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 스펙 economy-m1 수용 기준 1~4.
void main() {
  const sys = EconomySystem();
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  test('기준 1: 대포 Lv0에서 3회 강화하면 Lv3, 비용 합만큼 골드가 줄고 PartUpgraded 3개', () {
    final s0 = h.newGame(gold: BigNum.from(1000));
    final s = sys.handle(s0, const UpgradePart('cannon', times: 3), h.ctx)!;
    expect(s.ship.level('cannon'), 3);
    final cost = 10 * (1 + 1.15 + math.pow(1.15, 2));
    expect(s.wallet.gold.closeTo(BigNum.from(1000 - cost)), isTrue);
    expect(h.of<PartUpgraded>().map((e) => e.level), [1, 2, 3]);
    expect(h.of<SaveRequested>(), hasLength(1));
  });

  test('기준 2: 대포 Lv24 → 25에서 PartMilestone, 공격력 ×2 도약', () {
    final s0 = h.newGame(gold: BigNum.from(1e6)).copyWith(ship: const ShipState().withLevel('cannon', 24));
    final s = sys.handle(s0, const UpgradePart('cannon'), h.ctx)!;
    expect(s.ship.level('cannon'), 25);
    expect(h.of<PartMilestone>().single.level, 25);
    final t = EconomyHarness.tables.shipParts;
    expect(shipAttack(t, 25).closeTo(BigNum.from(4 * math.pow(1.11, 25) * 2)), isTrue);
  });

  test('기준 3: 골드가 모자라면 상태·이벤트 변화 없음', () {
    final s0 = h.newGame(gold: BigNum.from(9));
    final s = sys.handle(s0, const UpgradePart('cannon'), h.ctx)!;
    expect(s.ship.level('cannon'), 0);
    expect(s.wallet.gold, BigNum.from(9));
    expect(h.events, isEmpty);
  });

  test('times만큼 못 사면 살 수 있는 만큼만 산다', () {
    final s0 = h.newGame(gold: BigNum.from(25));
    final s = sys.handle(s0, const UpgradePart('cannon', times: 10), h.ctx)!;
    expect(s.ship.level('cannon'), 2); // 10 + 11.5 = 21.5 ≤ 25 < 21.5 + 13.225
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

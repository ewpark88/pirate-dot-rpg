import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// '모두 강화' 계획(사용자 피드백 2026-10-17 금고 피로, S4 버튼): 계획대로 UpgradePart를 보내면 같은 레벨·같은 골드, 남은 골드로는 더 못 산다.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;

  for (final gold in ['0', '35', '5e3', '2e6']) {
    test('골드 $gold: 계획 = 실제 강화 결과, 원래 상태는 그대로', () {
      final h = EconomyHarness();
      final s0 = h.newGame(gold: BigNum.parse(gold));
      final plan = bestUpgradePlan(s0, t);
      expect(s0.wallet.gold, BigNum.parse(gold), reason: '상태를 바꾸지 않는다');
      var s = s0;
      for (final e in plan.levels.entries) {
        s = sys.handle(s, UpgradePart(e.key, times: e.value), h.ctx) ?? s;
      }
      expect({for (final p in t.shipParts.parts) p.id: s.ship.level(p.id)}, plan.after);
      expect((s0.wallet.gold - s.wallet.gold).closeTo(plan.cost), isTrue);
      expect(autoUpgradePick(s, t), isNull, reason: '남은 골드로 살 수 있는 강화가 없다');
      if (gold == '0') expect(plan.levels, isEmpty);
    });
  }

  test('많은 골드면 여러 부위를 고루 올린다(가장 싼 것부터)', () {
    final plan = bestUpgradePlan(EconomyHarness().newGame(gold: BigNum.parse('1e9')), t);
    expect(plan.levels.length, greaterThanOrEqualTo(3));
  });
}

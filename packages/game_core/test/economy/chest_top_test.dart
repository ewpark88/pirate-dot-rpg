import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/chest.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 탑다운 보물상자 위치 (platform-topdown-render-check a): 카메라 사각형 안, 배 둘레 밖.
void main() {
  final t = EconomyHarness.tables;
  final top = t.waves.raw.obj('top');

  test('top이면 배 중심에서 shipRadius + chestMargin 밖, 보이는 사각형(viewWidth×viewHeight) 안', () {
    for (var seed = 1; seed <= 200; seed++) {
      final h = EconomyHarness(seed: seed);
      final s0 = h.newGame();
      final c = spawnChest(s0, h.ctx).battle!.chest!;
      final dx = c.x - top.number('shipX');
      final dy = c.y - top.number('shipY');
      final margin = top.number('chestMargin');
      expect(
        math.sqrt(dx * dx + dy * dy),
        greaterThanOrEqualTo(top.number('shipRadius') + margin - 1e-9),
        reason: 'seed $seed',
      );
      expect(dx.abs(), lessThanOrEqualTo(top.number('viewWidth') / 2 - margin + 1e-9), reason: 'seed $seed');
      expect(dy.abs(), lessThanOrEqualTo(top.number('viewHeight') / 2 - margin + 1e-9), reason: 'seed $seed');
    }
  });

  test('옆모습은 그대로 (필드 폭 비율·수면 높이)', () {
    final h = EconomyHarness();
    final c = spawnChest(h.newGame().copyWith(settings: const Settings(battleView: 'side')), h.ctx).battle!.chest!;
    expect(c.y, t.waves.raw.obj('field').obj('laneY').number('surface'));
  });

  test('ShipDamaged.fromX·fromY 선택 키 왕복, 없으면 본문에 없음', () {
    const plain = ShipDamaged(1, amount: BigNum.one, hpRatio: 0.5);
    expect(plain.toJson().containsKey('fromX'), isFalse);
    const hit = ShipDamaged(1, amount: BigNum.one, hpRatio: 0.5, fromX: 10, fromY: 20);
    final back = GameEvent.fromJson(hit.toJson()) as ShipDamaged;
    expect([back.fromX, back.fromY], [10, 20]);
  });
}

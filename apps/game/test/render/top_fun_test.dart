import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';

import 'helpers.dart';

void main() {
  List<RecordedTick> rec(List<GameEvent> at10) => [
    for (var t = 0; t < 40; t++)
      RecordedTick(
        BattleView(
          tick: t,
          shipHp: BigNum.from(1),
          shipHpMax: BigNum.from(1),
          mode: 'top',
          enemies: const [EnemyView(id: 7, kind: 'goldfish', x: 100, y: 170, hpRatio: 1)],
        ),
        t == 10 ? at10 : const [],
      ),
  ];

  BattleScene run(List<GameEvent> e) {
    final s = BattleScene(tables, rec(e));
    while (s.player.position < 10.5) {
      s.update(10);
    }
    return s;
  }

  test('피버 시작: 금빛 번쩍·흔들림', () {
    final s = run([const FeverStarted(10, untilTick: 100)]);
    expect(s.moments.feverFlashMs, greaterThan(0));
    expect(s.shake.peak, greaterThan(0));
  });

  test('황금 물고기 잡힘: 금 숫자 + 금화가 배로(금액 그대로)', () {
    final s = run([GoldfishCaught(10, targetId: 7, gold: BigNum.from(500))]);
    expect(s.numbers.active.any((n) => n.kind == DamageKind.crit && n.amount.toDouble() == 500), isTrue);
    final coin = s.coins.active.singleWhere((c) => c.amount.toDouble() == 500);
    expect((coin.toX, coin.toY), (s.topShip.dx, s.topShip.dy));
  });
}

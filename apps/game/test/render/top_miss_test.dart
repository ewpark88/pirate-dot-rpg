import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

/// S1 '공격이 0으로 표시되면 MISS로': 0으로 보이는 피해(1 미만 포함)는 숫자를 띄우지 않고 MISS(보호막이면 BLOCK).
void main() {
  List<RecordedTick> rec(BigNum amount, {bool shielded = false}) => [
    for (var t = 0; t < 20; t++)
      RecordedTick(
        BattleView(
          tick: t,
          shipHp: BigNum.from(1),
          shipHpMax: BigNum.from(1),
          mode: 'top',
          enemies: [EnemyView(id: 7, kind: 'crab', x: 100, y: 120, hpRatio: 1, shielded: shielded)],
        ),
        t == 10 ? [Damage(10, targetId: 7, amount: amount, crit: true, crewId: 'octo')] : const [],
      ),
  ];

  BattleScene run(List<RecordedTick> r) {
    final s = BattleScene(tables, r);
    while (s.player.position < 10.5) {
      s.update(10);
    }
    return s;
  }

  test('피해 0.4 → 숫자 없음(MISS)', () {
    expect(run(rec(BigNum.from(0.4))).numbers.active, isEmpty);
  });

  test('피해 5 → 숫자', () {
    expect(run(rec(BigNum.from(5))).numbers.active, hasLength(1));
  });

  test('보호막에 막힌 0 → 숫자 없음(BLOCK)', () {
    expect(run(rec(BigNum.zero, shielded: true)).numbers.active, isEmpty);
  });
}

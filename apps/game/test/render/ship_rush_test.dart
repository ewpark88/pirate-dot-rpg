import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/top/ship_turn.dart';

import 'helpers.dart';

/// 배 이동 연출(S1 '배가 느리게 움직여 재미없다' — S5 배 이동 v2): 엔진 키 없이 배 자리 변화로 빠르기를 읽어
/// 질주 정도(rush)를 낸다 — 멈춰 있으면 0, 빠르게(틱당 10단위 = 200단위/초) 달리면 가득, 질주 시작 순간 물보라.
void main() {
  List<RecordedTick> rec(double perTick) => [
    for (var t = 0; t < 60; t++)
      RecordedTick(
        BattleView(
          tick: t,
          shipHp: BigNum.from(1),
          shipHpMax: BigNum.from(1),
          mode: 'top',
          shipX: 100 + t * perTick,
          shipY: 300,
        ),
        const [],
      ),
  ];

  double run(double perTick, {void Function(BattleScene s)? check}) {
    final s = BattleScene(tables, rec(perTick));
    final turn = ShipTurn(s);
    while (s.player.position < 40) {
      s.update(16);
      turn.update(s.topShip.dx, s.clockMs, 16);
    }
    check?.call(s);
    return turn.rush;
  }

  test('멈춘 배는 질주 0, 빠른 배는 질주 가득', () {
    expect(run(0), 0);
    expect(run(10), 1);
  });
}

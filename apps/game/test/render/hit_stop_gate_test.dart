import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

/// 히트스톱 거르기(S5 자료 — 탑에서 초당 3.6회 멈칫): 엔진이 0.25초마다 멈춰도 렌더는 초당 1.5회까지만 실제로 멈춘다.
void main() {
  test('0.25초마다 오는 히트스톱 → 5초에 8번 이하로만 멈춤', () {
    final rec = [
      for (var t = 0; t < 100; t++)
        RecordedTick(
          BattleView(
            tick: t,
            shipHp: BigNum.from(1),
            shipHpMax: BigNum.from(1),
            mode: 'top',
            hitStopTicks: t % 5 == 1 || t % 5 == 2 ? 1 : 0,
          ),
          t % 5 == 0 ? [HitStop(t, ticks: 2, reason: 'crit')] : const [],
        ),
    ];
    final s = BattleScene(tables, rec, loop: false);
    while (s.player.position < 98) {
      s.update(16);
    }
    expect(s.player.gate.honored, inInclusiveRange(5, 8));
  });
}

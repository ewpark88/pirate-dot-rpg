import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

void main() {
  test('부품 단계 축하: ShipLookChanged면 그 부위가 빛나고 시간이 지나면 꺼진다', () {
    final ticks = [
      for (var i = 0; i < 120; i++)
        tickOf(i, events: i == 1 ? [const ShipLookChanged(1, part: 'sail', stage: 3)] : const []),
    ];
    final s = BattleScene(tables, ticks)..update(tickMs * 1.5);
    while (s.player.position < 1.1) {
      s.update(10);
    }
    expect(s.moments.glowPart, 'sail');
    expect(s.moments.glowMs, greaterThan(0));
    for (var i = 0; i < 300; i++) {
      s.update(10);
    }
    expect(s.moments.glowMs, lessThanOrEqualTo(0));
  });

  test('배 피격: 빨간 숫자, 무리전에서 HP 0이면 침몰 연출(보스전이면 없음 — 보스 실패 연출)', () {
    List<RecordedTick> rec({required bool boss}) => [
      for (var i = 0; i < 80; i++)
        RecordedTick(
          BattleView(tick: i, shipHp: BigNum.from(60), shipHpMax: BigNum.from(60), bossActive: boss),
          i == 2 ? [ShipDamaged(2, amount: BigNum.from(60), hpRatio: 0)] : const [],
        ),
    ];
    final s = BattleScene(tables, rec(boss: false));
    while (s.player.position < 2.2) {
      s.update(10);
    }
    expect(s.numbers.active.any((n) => n.kind == DamageKind.ship), isTrue);
    expect(s.moments.sinkMs, greaterThan(0));
    final b = BattleScene(tables, rec(boss: true));
    while (b.player.position < 2.2) {
      b.update(10);
    }
    expect(b.moments.sinkMs, 0);
  });
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/ship_geometry.dart';

import 'helpers.dart';

void main() {
  test('배 1.3배(정수 픽셀 반올림) — 뱃머리 오른쪽 끝·포구 높이는 배율과 무관, 포구 끝이 발사 위치', () {
    final s = BattleScene(tables, marching(3))..layout = battleFrameFor(const Size(384, 374), 2.8125);
    final sc = ShipGeometry.scale(s);
    expect(sc * s.layout.k, closeTo((sc * s.layout.k).roundToDouble(), 1e-9), reason: '정수 물리 픽셀');
    expect(sc, inInclusiveRange(1.2, 1.4));
    final box = ShipGeometry.box(s, 62, 48);
    expect(box.right, kShipLeft + kShipWidth);
    expect(box.width, closeTo(62 * sc, 1e-9));
    final tip = ShipGeometry.cannonTip(s);
    expect(tip.dx, lessThan(box.right));
    expect(tip.dy, inInclusiveRange(box.top, box.bottom));
    expect(BattleScene(tables, marching(3)).layout.k, 1);
    expect(ShipGeometry.scale(BattleScene(tables, marching(3))), 1, reason: '기본(골든) 배치는 1배');
  });

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
}

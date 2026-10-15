import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

void main() {
  const devices = [('360x640', 360.0, 3.0), ('s24', 384.0, 2.8125), ('411x891', 411.0, 2.625), ('tablet', 800.0, 2.0)];
  for (final (name, w, dpr) in devices) {
    test('탑다운 배치 $name: 배율은 폭으로만(시트를 끌어도 그대로), 화면 가로 약 180단위, 배는 보이는 전장 가로 가운데·세로 63%', () {
      final closed = topFrameFor(Size(w, 620), dpr);
      for (final h in [620.0, 500.0, 340.0, 260.0]) {
        final f = topFrameFor(Size(w, h), dpr);
        expect(f.k, closed.k, reason: '높이 $h');
        expect(f.shipScreen.dy, closeTo(f.band.slotBand.top * TopFrame.kShipAt, 1e-6));
        expect(f.shipScreen.dx, closeTo(w / 2, 1e-6));
      }
      expect(closed.viewUnits.width, inInclusiveRange(176, 200));
    });
  }
}

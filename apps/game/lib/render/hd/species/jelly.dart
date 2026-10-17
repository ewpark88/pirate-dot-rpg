import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, RadialGradient;
import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 해파리(td_enemy:jelly): 반투명 돔이 오므렸다 펴고(숨쉬기) 촉수 5가닥이 꿈틀.
const jelly = HdSpecies(_jelly, extent: 1.3, ground: 1.2);

void _jelly(HdKit k, Canvas c, double r, double t) {
  final pulse = 1 + k.wave(t, 1) * 0.05;
  for (var i = 0; i < 5; i++) {
    k.tentacle(
      c,
      Offset((i - 2) * r * 0.3, r * 0.2),
      math.pi / 2,
      r * 0.88,
      2 * math.pi * t / HdKit.loopMs + i,
      const Color(0xFFD86CF0),
      k.ink.strokeWidth * 1.1,
    );
  }
  final dome = Path()
    ..moveTo(-r * 0.95 * pulse, r * 0.25)
    ..cubicTo(-r * pulse, -r * 1.15, r * pulse, -r * 1.15, r * 0.95 * pulse, r * 0.25)
    ..quadraticBezierTo(r * 0.5, r * 0.4, 0, r * 0.28)
    ..quadraticBezierTo(-r * 0.5, r * 0.4, -r * 0.95 * pulse, r * 0.25)
    ..close();
  // 반투명 돔: 세로 그라데이션 대신 왼쪽 위에서 퍼지는 원형(젤리 느낌).
  k.fill
    ..color = const Color(0xFFFFFFFF)
    ..shader = const RadialGradient(
      center: Alignment(-0.3, -0.5),
      colors: [Color(0xF0FFD6FA), Color(0xE0F08AE8), Color(0xD0B04ADC)],
    ).createShader(dome.getBounds());
  c.drawPath(dome, k.fill);
  k.fill.shader = null;
  c.drawPath(dome, k.ink);
  k.fill.color = const Color(0xAAFFFFFF);
  c.drawOval(Rect.fromCenter(center: Offset(-r * 0.4, -r * 0.55), width: r * 0.42, height: r * 0.22), k.fill);
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.32, -r * 0.2), r * 0.3);
  }
  k.smile(c, Offset(0, r * 0.02), r * 0.24);
}

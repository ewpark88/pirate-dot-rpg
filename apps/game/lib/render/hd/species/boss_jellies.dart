import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, RadialGradient;
import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 해파리 여왕(td_boss:jelly_queen): 금관 쓴 보라 돔 + 긴 촉수 8가닥, 돔이 오므렸다 펴며 떠오른다.
const jellyQueen = HdSpecies(_jellyQueen, extent: 1.5, ground: 1.15);

/// 유령 해파리(td_boss:phantom_jelly): 반투명 청록 돔, 속이 비치고 촉수 끝이 흐려진다 — 졸린 눈으로 둥실.
const phantomJelly = HdSpecies(_phantomJelly, extent: 1.45, ground: 1.15);

void _jellyQueen(HdKit k, Canvas c, double r, double t) => _jellyBoss(
  k,
  c,
  r,
  t,
  colors: const [Color(0xFFFFE6FF), Color(0xFFE09AF8), Color(0xFF9A4ADC)],
  arm: const Color(0xFFC060F0),
  arms: 8,
  crown: true,
  ghost: false,
);

void _phantomJelly(HdKit k, Canvas c, double r, double t) => _jellyBoss(
  k,
  c,
  r,
  t,
  colors: const [Color(0xE0E8FFFF), Color(0xC08AE8F0), Color(0xA03AA8C8)],
  arm: const Color(0xB070D8E8),
  arms: 6,
  crown: false,
  ghost: true,
);

void _jellyBoss(
  HdKit k,
  Canvas c,
  double r,
  double t, {
  required List<Color> colors,
  required Color arm,
  required int arms,
  required bool crown,
  required bool ghost,
}) {
  final pulse = k.wave(t, 1);
  final lift = -pulse * r * 0.06; // 오므릴 때 떠오름
  // 촉수(뒤): 길게 늘어져 꿈틀, 바깥 것은 옆으로 퍼짐
  for (var i = 0; i < arms; i++) {
    final u = i / (arms - 1) * 2 - 1; // -1 ~ 1
    final from = Offset(u * r * 0.7, r * 0.2 + lift);
    k.tentacle(
      c,
      from,
      math.pi / 2 - u * 0.5,
      r * (1.0 - u.abs() * 0.2),
      2 * math.pi * t / HdKit.loopMs + i * 0.9,
      arm,
      r * 0.12,
      n: 5,
    );
  }
  // 돔(오므리면 좁고 높게)
  final wx = 1 + pulse * 0.06;
  final dome = Path()
    ..moveTo(-r * 1.0 * wx, r * 0.25 + lift)
    ..cubicTo(-r * 1.05 * wx, -r * 1.2, r * 1.05 * wx, -r * 1.2, r * 1.0 * wx, r * 0.25 + lift)
    ..quadraticBezierTo(r * 0.75, r * 0.45 + lift, r * 0.5, r * 0.3 + lift)
    ..quadraticBezierTo(r * 0.25, r * 0.45 + lift, 0, r * 0.3 + lift)
    ..quadraticBezierTo(-r * 0.25, r * 0.45 + lift, -r * 0.5, r * 0.3 + lift)
    ..quadraticBezierTo(-r * 0.75, r * 0.45 + lift, -r * 1.0 * wx, r * 0.25 + lift)
    ..close();
  k.fill
    ..color = const Color(0xFFFFFFFF)
    ..shader = RadialGradient(center: const Alignment(-0.3, -0.5), colors: colors).createShader(dome.getBounds());
  c.drawPath(dome, k.fill);
  k.fill.shader = null;
  c.drawPath(dome, k.ink);
  k.shine(c, dome.getBounds());
  // 돔 무늬: 여왕은 진주 점, 유령은 속에 비치는 소용돌이
  if (ghost) {
    final w = k.ink.strokeWidth;
    k.ink
      ..strokeWidth = w * 0.4
      ..color = const Color(0x661A1424);
    c.drawArc(
      Rect.fromCenter(center: Offset(r * 0.45, -r * 0.45), width: r * 0.3, height: r * 0.3),
      0,
      4.5,
      false,
      k.ink,
    );
    k.ink
      ..strokeWidth = w
      ..color = HdKit.inkColor;
  } else {
    k.spots(c, r, const [
      (-0.62, -0.1, 0.05),
      (0.62, -0.1, 0.05),
      (-0.35, -0.72, 0.04),
      (0.4, -0.7, 0.04),
    ], const Color(0xCCFFFFFF));
  }
  // 얼굴
  final face = Offset(0, -r * 0.25 + lift);
  if (ghost) {
    // 졸린 눈(반쯤 감김) + 작은 o 입
    for (final s in const [-1.0, 1.0]) {
      final at = face + Offset(s * r * 0.32, 0);
      k.eye(c, at, r * 0.32, look: 0.2);
      k.fill.color = colors[1].withValues(alpha: 1);
      c
        ..drawRect(Rect.fromLTRB(at.dx - r * 0.2, at.dy - r * 0.24, at.dx + r * 0.2, at.dy - r * 0.02), k.fill)
        ..drawLine(at + Offset(-r * 0.17, -r * 0.02), at + Offset(r * 0.17, -r * 0.02), k.ink);
    }
    k.mouth(c, Path()..addOval(Rect.fromCenter(center: face + Offset(0, r * 0.25), width: r * 0.14, height: r * 0.18)));
  } else {
    for (final s in const [-1.0, 1.0]) {
      k.eye(c, face + Offset(s * r * 0.34, 0), r * 0.36, angry: true, look: -0.3);
    }
    k
      ..mouth(
        c,
        Path()
          ..moveTo(face.dx - r * 0.2, face.dy + r * 0.24)
          ..quadraticBezierTo(face.dx, face.dy + r * 0.48 + pulse * r * 0.04, face.dx + r * 0.2, face.dy + r * 0.24)
          ..close(),
      )
      ..tooth(c, face + Offset(-r * 0.14, r * 0.23), r * 0.1, r * 0.09)
      ..tooth(c, face + Offset(r * 0.04, r * 0.23), r * 0.1, r * 0.09)
      ..cheeks(c, face + Offset(0, r * 0.2), r * 0.58, r * 0.2);
  }
  if (crown) k.crown(c, Offset(0, -r * 0.86 + lift), r * 0.62);
}

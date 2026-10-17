import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 크라켄(td_boss:kraken): 금관 쓴 보라 문어 왕 — 촉수 8가닥이 번갈아 꿈틀, 머리가 숨쉬듯 부푼다.
const kraken = HdSpecies(_kraken, extent: 1.5, ground: 0.95);

void _kraken(HdKit k, Canvas c, double r, double t) {
  const purple = Color(0xFFB062FF);
  const purpleD = Color(0xFF5A2AA8);
  final breathe = 1 + k.wave(t, 1) * 0.03;
  // 촉수 8(뒤 → 앞), 끝에 빨판
  for (var i = 0; i < 8; i++) {
    final a = math.pi * (0.15 + 0.7 * i / 7);
    final wig = k.wave(t, 1, i.toDouble()) * 0.25;
    final ex = math.cos(a + wig * 0.3) * r * 1.35;
    final ey = r * 0.3 + math.sin(a) * r * 0.85;
    final p = Path()
      ..moveTo(math.cos(a) * r * 0.4, r * 0.3)
      ..quadraticBezierTo(math.cos(a - wig) * r * 1.1, r * 0.2 + math.sin(a) * r * 0.2, ex, ey);
    k.limb(c, p, i.isEven ? purple : const Color(0xFF9A4AF0), r * 0.3);
    k.fill.color = const Color(0xFFFFC8F0);
    c.drawCircle(Offset(ex, ey) * 0.82 + Offset(0, r * 0.05), r * 0.05, k.fill);
  }
  c
    ..save()
    ..translate(0, r * 0.35)
    ..scale(breathe, 2 - breathe)
    ..translate(0, -r * 0.35);
  final head = Path()
    ..moveTo(-r * 0.85, r * 0.35)
    ..cubicTo(-r * 1.05, -r * 1.3, r * 1.05, -r * 1.3, r * 0.85, r * 0.35)
    ..quadraticBezierTo(0, r * 0.6, -r * 0.85, r * 0.35)
    ..close();
  k
    ..blob(c, head, const Color(0xFFD8A0FF), purpleD)
    ..spots(c, r, const [(-0.45, -0.55, 0.12), (0.5, -0.4, 0.1), (0.1, -0.85, 0.08)], const Color(0x667A3AD8))
    ..crown(c, Offset(0, -r * 0.92), r * 0.7);
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.36, -r * 0.2), r * 0.42, angry: true, look: s * -0.4);
  }
  k.mouth(
    c,
    Path()
      ..moveTo(-r * 0.3, r * 0.15)
      ..quadraticBezierTo(0, r * 0.42, r * 0.3, r * 0.15)
      ..close(),
  );
  for (final s in const [-1.0, 1.0]) {
    k.tooth(c, Offset(s > 0 ? r * 0.03 : -r * 0.18, r * 0.18), r * 0.15, r * 0.12);
  }
  c.restore();
}

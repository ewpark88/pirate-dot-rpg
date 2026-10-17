import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, RadialGradient;
import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 용암 슬라임(td_boss:lava_slime): 굳은 껍질 박힌 주황 용암 덩어리 — 부글부글 출렁이고 정수리에서 불똥이 튄다.
const lavaSlime = HdSpecies(_lavaSlime, extent: 1.5, ground: 0.85);

void _lavaSlime(HdKit k, Canvas c, double r, double t) {
  final sq = k.wave(t, 2) * 0.04;
  c
    ..save()
    ..translate(0, r * 0.7)
    ..scale(1 + sq, 1 - sq)
    ..translate(0, -r * 0.7);
  final body = Path()
    ..moveTo(-r * 1.05, r * 0.55)
    ..cubicTo(-r * 1.2, -r * 0.35, -r * 0.6, -r * 0.85, 0, -r * 0.85)
    ..cubicTo(r * 0.6, -r * 0.85, r * 1.2, -r * 0.35, r * 1.05, r * 0.55)
    ..quadraticBezierTo(0, r * 0.85, -r * 1.05, r * 0.55)
    ..close();
  k.fill
    ..color = const Color(0xFFFFFFFF)
    ..shader = const RadialGradient(
      center: Alignment(-0.3, -0.4),
      radius: 0.95,
      colors: [Color(0xFFFFE07A), Color(0xFFFF8A2A), Color(0xFFC03A12)],
    ).createShader(body.getBounds());
  c.drawPath(body, k.fill);
  k.fill.shader = null;
  c.drawPath(body, k.ink);
  k.shine(c, body.getBounds());
  // 굳은 현무암 껍질 조각(정수리 둘레)
  for (final (x, y, s) in const [
    (-0.7, -0.35, 0.16),
    (-0.35, -0.72, 0.14),
    (0.1, -0.82, 0.13),
    (0.5, -0.65, 0.15),
    (0.82, -0.25, 0.12),
  ]) {
    final p = Path()
      ..moveTo(x * r - s * r, y * r)
      ..lineTo(x * r - s * r * 0.3, y * r - s * r * 0.8)
      ..lineTo(x * r + s * r * 0.8, y * r - s * r * 0.4)
      ..lineTo(x * r + s * r * 0.6, y * r + s * r * 0.5)
      ..close();
    k.blob(c, p, const Color(0xFF6A5A5A), const Color(0xFF2A2020), gloss: false, line: 0.6);
  }
  // 부글 거품(위로 커졌다 터짐)
  for (final (x, ph) in const [(-0.5, 0.0), (0.45, 2.1), (0.05, 4.2)]) {
    final u = (k.wave(t, 1, ph) + 1) / 2;
    k.fill.color = Color.fromRGBO(255, 230, 140, 0.9 - u * 0.5);
    c.drawCircle(Offset(x * r, r * (0.35 - u * 0.25)), r * (0.04 + u * 0.06), k.fill);
  }
  // 얼굴: 화난 눈 + 크게 벌린 입(용암 속)
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.36, -r * 0.2), r * 0.36, angry: true, look: -0.2);
  }
  final open = (k.wave(t, 1) + 1) * r * 0.04;
  k
    ..mouth(
      c,
      Path()
        ..moveTo(-r * 0.3, r * 0.14)
        ..quadraticBezierTo(0, r * 0.06, r * 0.3, r * 0.14)
        ..quadraticBezierTo(r * 0.24, r * 0.48 + open, 0, r * 0.5 + open)
        ..quadraticBezierTo(-r * 0.24, r * 0.48 + open, -r * 0.3, r * 0.14)
        ..close(),
    )
    ..tooth(c, Offset(-r * 0.22, r * 0.11), r * 0.12, r * 0.12)
    ..tooth(c, Offset(r * 0.1, r * 0.11), r * 0.12, r * 0.12);
  c.restore();
  // 불똥(정수리 위로 튀어 떨어짐)
  for (final (x, ph) in const [(-0.2, 0.0), (0.3, 3.0)]) {
    final u = (t / HdKit.loopMs + ph / 6.283) % 1;
    k.fill.color = Color.fromRGBO(255, 180, 60, 1 - u);
    c.drawCircle(Offset(x * r + u * x * r, -r * 0.95 - r * 0.5 * (4 * u * (1 - u))), r * 0.05, k.fill);
  }
}

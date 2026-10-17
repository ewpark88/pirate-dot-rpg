import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 심해 문어(td_boss:deep_octopus): 남색 문어 — 촉수 8가닥이 옆으로 넓게 꿈틀, 노란 눈이 빛나고 먹물 방울이 샌다.
const deepOctopus = HdSpecies(_deepOctopus, extent: 1.55, ground: 0.95);

/// 대왕 오징어(td_boss:giant_squid): 분홍 오징어 — 위쪽 삼각 지느러미, 큰 파란 눈, 긴 다리 10개가 아래로 흔들린다.
const giantSquid = HdSpecies(_giantSquid, extent: 1.55, ground: 1.1);

void _deepOctopus(HdKit k, Canvas c, double r, double t) {
  const navy = Color(0xFF5A78D8);
  const navyD = Color(0xFF1E2E78);
  final breathe = 1 + k.wave(t, 1) * 0.04;
  // 촉수 8: 뒤 4(옆으로 넓게) → 앞 4(아래로) — 선이 겹쳐 검게 뭉치지 않게 벌린다
  for (final (i, a, len) in const [
    (0, 0.05, 1.05),
    (1, 3.09, 1.05),
    (2, 0.55, 1.1),
    (3, 2.59, 1.1),
    (4, 1.05, 1.05),
    (5, 2.09, 1.05),
    (6, 1.4, 0.95),
    (7, 1.74, 0.95),
  ]) {
    final from = Offset(math.cos(a) * r * 0.4, r * 0.25);
    k.tentacle(
      c,
      from,
      a,
      r * len,
      2 * math.pi * t / HdKit.loopMs + i * 0.8,
      i < 4 ? const Color(0xFF4A66C8) : navy,
      r * 0.22,
      n: 5,
    );
  }
  c
    ..save()
    ..translate(0, r * 0.3)
    ..scale(breathe, 2 - breathe)
    ..translate(0, -r * 0.3);
  final head = Path()
    ..moveTo(-r * 0.8, r * 0.35)
    ..cubicTo(-r * 1.0, -r * 1.2, r * 1.0, -r * 1.2, r * 0.8, r * 0.35)
    ..quadraticBezierTo(0, r * 0.55, -r * 0.8, r * 0.35)
    ..close();
  k
    ..blob(c, head, const Color(0xFF8AA4F0), navyD)
    ..spots(c, r, const [(-0.5, -0.5, 0.1), (0.48, -0.6, 0.08), (0.1, -0.85, 0.07)], const Color(0x551E2E78));
  // 노란 빛나는 눈(세로 동공)
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.34, -r * 0.18);
    k.fill.color = const Color(0x55FFE45A);
    c.drawCircle(at, r * 0.3, k.fill);
    final eye = Rect.fromCenter(center: at, width: r * 0.36, height: r * 0.34);
    k.fill.color = const Color(0xFFFFE45A);
    c
      ..drawOval(eye, k.fill)
      ..drawOval(eye, k.ink);
    k.fill.color = HdKit.inkColor;
    c
      ..drawOval(Rect.fromCenter(center: at, width: r * 0.09, height: r * 0.26), k.fill)
      ..drawLine(at + Offset(-s * r * 0.24, -r * 0.3), at + Offset(s * r * 0.18, -r * 0.18), k.ink);
  }
  k.mouth(
    c,
    Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.18), width: r * 0.22, height: r * (0.14 + 0.06 * breathe))),
  );
  c.restore();
  // 먹물 방울(입에서 아래로 떨어짐)
  final u = (t / HdKit.loopMs) % 1;
  k.fill.color = Color.fromRGBO(30, 20, 50, 0.85 * (1 - u));
  c.drawCircle(Offset(0, r * (0.35 + u * 0.5)), r * (0.08 - u * 0.03), k.fill);
}

void _giantSquid(HdKit k, Canvas c, double r, double t) {
  const pink = Color(0xFFFFB4C8);
  const pinkD = Color(0xFFC0506E);
  final pulse = k.wave(t, 1);
  // 다리 8 + 긴 촉완 2(바깥) — 부채처럼 벌리고, 외곽선을 먼저 다 그린 뒤 색을 칠해 겹친 자리가 검게 뭉치지 않게
  final legs = <(Path, double, Color)>[];
  for (var i = 0; i < 10; i++) {
    final u = i / 9 * 2 - 1;
    final long = i == 0 || i == 9;
    final from = Offset(u * r * 0.4, r * 0.32);
    final a = math.pi / 2 + u * 1.0;
    final d = Offset(math.cos(a), math.sin(a));
    final side = Offset(-d.dy, d.dx);
    final len = r * (long ? 1.2 : 0.85);
    final p = Path()..moveTo(from.dx, from.dy);
    for (var j = 1; j <= 5; j++) {
      final q = from + d * (len * j / 5) + side * (k.wave(t, 1, i * 0.7 + j * 0.6) * len * 0.05 * j / 5 * 2);
      p.lineTo(q.dx, q.dy);
    }
    legs.add((p, r * (long ? 0.12 : 0.17), i.isEven ? pink : const Color(0xFFF59AB4)));
  }
  final ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true
    ..color = HdKit.inkColor;
  for (final (p, w, _) in legs) {
    c.drawPath(p, ink..strokeWidth = w + k.ink.strokeWidth * 2);
  }
  for (final (p, w, col) in legs) {
    c.drawPath(
      p,
      ink
        ..strokeWidth = w
        ..color = col,
    );
    ink.color = HdKit.inkColor;
  }
  // 몸통(위로 긴 원뿔) + 삼각 지느러미
  c
    ..save()
    ..translate(0, -pulse * r * 0.05);
  for (final s in const [-1.0, 1.0]) {
    final fin = Path()
      ..moveTo(s * r * 0.15, -r * 1.25)
      ..lineTo(s * r * (0.75 + pulse * 0.05), -r * 0.85)
      ..lineTo(s * r * 0.35, -r * 0.6)
      ..close();
    k.blob(c, fin, const Color(0xFFFFD0DC), pinkD, gloss: false);
  }
  final mantle = Path()
    ..moveTo(0, -r * 1.35)
    ..cubicTo(r * 0.55, -r * 1.0, r * 0.62, r * 0.1, r * 0.55, r * 0.4)
    ..quadraticBezierTo(0, r * 0.55, -r * 0.55, r * 0.4)
    ..cubicTo(-r * 0.62, r * 0.1, -r * 0.55, -r * 1.0, 0, -r * 1.35)
    ..close();
  k
    ..blob(c, mantle, const Color(0xFFFFD8E2), pinkD)
    ..spots(c, r, const [
      (-0.25, -0.7, 0.06),
      (0.28, -0.5, 0.05),
      (-0.1, -1.0, 0.04),
      (0.2, -0.95, 0.04),
    ], const Color(0x66C0506E));
  // 큰 파란 눈
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.3, r * 0.05);
    final ring = Rect.fromCenter(center: at, width: r * 0.42, height: r * 0.44);
    k.fill.color = const Color(0xFF6AC0FF);
    c
      ..drawOval(ring, k.fill)
      ..drawOval(ring, k.ink);
    k.eye(c, at, r * 0.3, angry: true, look: -s * 0.3);
  }
  c.restore();
}

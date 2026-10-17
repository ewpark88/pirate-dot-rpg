import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 불꽃 장어(td_boss:flame_eel): 물에서 S자로 솟은 주황 장어 — 등에 노란 번개 무늬, 머리 위 불꽃이 일렁인다.
const flameEel = HdSpecies(_flameEel, extent: 1.5, ground: 1);

/// 거대 바다뱀(td_boss:great_serpent): 초록 바다뱀 — 붉은 띠 무늬, 더듬이 둘, 혀를 날름.
const greatSerpent = HdSpecies(_greatSerpent, extent: 1.5, ground: 1);

void _flameEel(HdKit k, Canvas c, double r, double t) => _serpent(
  k,
  c,
  r,
  t,
  body: const Color(0xFFFF8A3A),
  bodyD: const Color(0xFFB8401A),
  mark: const Color(0xFFFFE04A),
  flame: true,
);

void _greatSerpent(HdKit k, Canvas c, double r, double t) => _serpent(
  k,
  c,
  r,
  t,
  body: const Color(0xFF5ACC7A),
  bodyD: const Color(0xFF1E7A4A),
  mark: const Color(0xFFE8384A),
  flame: false,
);

void _serpent(
  HdKit k,
  Canvas c,
  double r,
  double t, {
  required Color body,
  required Color bodyD,
  required Color mark,
  required bool flame,
}) {
  final sway = k.wave(t, 1) * r * 0.14;
  // 뒤 몸 고리(물 위로 반원)
  final up = r * (0.3 + k.wave(t, 1, 2) * 0.05);
  final arch = Path()
    ..moveTo(r * 0.55, r * 0.95)
    ..cubicTo(r * 0.55, r * 0.95 - up * 2, r * 1.15, r * 0.95 - up * 2, r * 1.15, r * 0.95)
    ..close();
  k.blob(c, arch, body, bodyD, gloss: false);
  _ring(k, c, Offset(r * 0.85, r * 0.95), r * 0.38);
  // 목(S자) + 등 무늬
  final neck = Path()
    ..moveTo(-r * 0.2, r * 0.95)
    ..cubicTo(-r * 0.9, r * 0.45, r * 0.6 + sway, 0, sway * 0.5, -r * 0.45);
  k.limb(c, neck, body, r * 0.42);
  k.fill.color = mark;
  for (final m in neck.computeMetrics()) {
    for (var i = 1; i < 6; i++) {
      final tg = m.getTangentForOffset(m.length * i / 6);
      if (tg == null) continue;
      final n = Offset(-tg.vector.dy, tg.vector.dx);
      final p = tg.position;
      if (flame) {
        // 번개 지그재그
        c.drawPath(
          Path()
            ..moveTo(p.dx + n.dx * r * 0.16, p.dy + n.dy * r * 0.16)
            ..lineTo(p.dx + tg.vector.dx * r * 0.08, p.dy + tg.vector.dy * r * 0.08)
            ..lineTo(p.dx - n.dx * r * 0.04, p.dy - n.dy * r * 0.04)
            ..lineTo(p.dx - n.dx * r * 0.16 + tg.vector.dx * r * 0.1, p.dy - n.dy * r * 0.16 + tg.vector.dy * r * 0.1)
            ..lineTo(p.dx + tg.vector.dx * r * 0.02, p.dy + tg.vector.dy * r * 0.02)
            ..close(),
          k.fill,
        );
      } else {
        c.drawLine(
          p + n * r * 0.18,
          p - n * r * 0.18,
          Paint()
            ..color = mark
            ..strokeWidth = r * 0.07
            ..isAntiAlias = true,
        );
      }
    }
  }
  _ring(k, c, Offset(-r * 0.2, r * 0.95), r * 0.45);
  // 머리
  c
    ..save()
    ..translate(sway * 0.5, -r * 0.5)
    ..scale(1.5); // 보스는 머리가 크게(2등신) — 선 두께는 그대로 보이게 나눈다
  final ink = k.ink.strokeWidth;
  k.ink.strokeWidth = ink / 1.5;
  if (flame) {
    final f = k.wave(t, 2) * r * 0.06;
    for (final (x, h, col) in const [(-0.14, 0.42, 0xFFFF5A2A), (0.12, 0.38, 0xFFFF5A2A), (0.0, 0.55, 0xFFFFC23A)]) {
      final p = Path()
        ..moveTo(x * r - r * 0.12, -r * 0.18)
        ..quadraticBezierTo(x * r - r * 0.1, -r * (0.18 + h) - f, x * r + r * 0.02, -r * (0.2 + h) - f)
        ..quadraticBezierTo(x * r + r * 0.04, -r * 0.3, x * r + r * 0.12, -r * 0.18)
        ..close();
      k.blob(c, p, Color(col), const Color(0xFFE0301A), gloss: false, line: 0.6);
    }
  } else {
    for (final s in const [-1.0, 1.0]) {
      final ant = Path()
        ..moveTo(s * r * 0.12, -r * 0.25)
        ..quadraticBezierTo(s * r * 0.2, -r * 0.55, s * r * (0.32 + k.wave(t, 2, s) * 0.03), -r * 0.6);
      k.limb(c, ant, mark, r * 0.05);
      k.fill.color = mark;
      c.drawCircle(Offset(s * r * 0.32, -r * 0.6), r * 0.06, k.fill);
    }
  }
  final head = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: r * 0.78, height: r * 0.62));
  k.blob(c, head, Color.lerp(body, const Color(0xFFFFFFFF), 0.25)!, bodyD);
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.17, -r * 0.06), r * 0.24, angry: true, look: -0.3);
  }
  // 입 + 송곳니, 바다뱀은 혀
  final open = (k.wave(t, 1, 1) + 1) / 2;
  k.mouth(
    c,
    Path()
      ..moveTo(-r * 0.16, r * 0.14)
      ..quadraticBezierTo(0, r * 0.1, r * 0.16, r * 0.14)
      ..quadraticBezierTo(0, r * 0.26 + open * r * 0.05, -r * 0.16, r * 0.14)
      ..close(),
  );
  if (!flame && open > 0.5) {
    k.limb(
      c,
      Path()
        ..moveTo(0, r * 0.22)
        ..lineTo(0, r * 0.32 + open * r * 0.08)
        ..moveTo(0, r * 0.32 + open * r * 0.08)
        ..lineTo(-r * 0.04, r * 0.38 + open * r * 0.08)
        ..moveTo(0, r * 0.32 + open * r * 0.08)
        ..lineTo(r * 0.04, r * 0.38 + open * r * 0.08),
      const Color(0xFFFF5A7A),
      r * 0.035,
    );
  }
  k
    ..tooth(c, Offset(-r * 0.13, r * 0.12), r * 0.07, r * 0.08)
    ..tooth(c, Offset(r * 0.06, r * 0.12), r * 0.07, r * 0.08);
  k.ink.strokeWidth = ink;
  c.restore();
}

/// 몸이 물을 뚫은 자리의 흰 물 고리.
void _ring(HdKit k, Canvas c, Offset at, double w) {
  k.fill.color = const Color(0xCCE8F8FF);
  c.drawOval(Rect.fromCenter(center: at, width: w * 2, height: w * 0.45), k.fill);
  k.fill.color = const Color(0x553A8AD0);
  c.drawOval(Rect.fromCenter(center: at + Offset(0, w * 0.04), width: w * 1.5, height: w * 0.25), k.fill);
}

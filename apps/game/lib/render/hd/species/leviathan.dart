import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 리바이어던(대보스 td_boss:leviathan): 바다에서 S자로 솟은 붉은 바다뱀 — 몸 고리가 물결처럼 오르내리고,
/// 뿔 달린 머리가 불빛 눈으로 내려다본다. 몸 고리 둘이 물에 잠겼다 나온다(물 고리).
const leviathan = HdSpecies(_leviathan, extent: 1.6, ground: 1);

void _leviathan(HdKit k, Canvas c, double r, double t) {
  const red = Color(0xFFE8503A);
  const redD = Color(0xFF7A1E22);
  const belly = Color(0xFFFFC46A);
  // 물에 잠긴 몸 고리 2개(뒤): 물 위로 반원만
  for (final (x, ph) in const [(0.95, 0.0), (-0.95, 2.0)]) {
    final up = r * (0.32 + k.wave(t, 1, ph) * 0.05);
    final arch = Path()
      ..moveTo(x * r - r * 0.32, r * 0.95)
      ..cubicTo(x * r - r * 0.32, r * 0.95 - up * 2, x * r + r * 0.32, r * 0.95 - up * 2, x * r + r * 0.32, r * 0.95)
      ..close();
    k.blob(c, arch, red, redD, gloss: false);
    _waterRing(k, c, Offset(x * r, r * 0.95), r * 0.42);
  }
  // 목(S자) — 아래 물에서 머리까지 굵은 줄 + 배 비늘 줄
  final sway = k.wave(t, 1) * r * 0.1;
  final neck = Path()
    ..moveTo(0, r * 0.95)
    ..cubicTo(r * 0.7, r * 0.45, -r * 0.6 + sway, -r * 0.1, sway * 0.6, -r * 0.55);
  k.limb(c, neck, red, r * 0.5);
  _scales(k, c, neck, r);
  _waterRing(k, c, Offset(0, r * 0.95), r * 0.5);
  // 등지느러미(목 뒤 옆으로 펼친 막)
  for (final s in const [-1.0, 1.0]) {
    final fin = Path()
      ..moveTo(sway * 0.6 + s * r * 0.2, -r * 0.55)
      ..quadraticBezierTo(s * r * 0.95, -r * 0.95 + k.wave(t, 2, s) * r * 0.05, s * r * 0.75, -r * 0.25)
      ..quadraticBezierTo(s * r * 0.5, -r * 0.3, sway * 0.6 + s * r * 0.25, -r * 0.3)
      ..close();
    k.blob(c, fin, const Color(0xFFFF9A5A), const Color(0xFFC04A2A), gloss: false);
  }
  // 머리(위에서 내려다봄): 넓은 턱·뿔 둘
  c
    ..save()
    ..translate(sway * 0.6, -r * 0.82);
  for (final s in const [-1.0, 1.0]) {
    final horn = Path()
      ..moveTo(s * r * 0.22, -r * 0.2)
      ..quadraticBezierTo(s * r * 0.45, -r * 0.55, s * r * 0.35, -r * 0.72)
      ..quadraticBezierTo(s * r * 0.32, -r * 0.42, s * r * 0.08, -r * 0.25)
      ..close();
    k.blob(c, horn, const Color(0xFFFFF0C8), const Color(0xFFC8A060), gloss: false, line: 0.7);
  }
  final head = Path()
    ..moveTo(-r * 0.48, r * 0.05)
    ..cubicTo(-r * 0.55, -r * 0.4, -r * 0.25, -r * 0.42, 0, -r * 0.42)
    ..cubicTo(r * 0.25, -r * 0.42, r * 0.55, -r * 0.4, r * 0.48, r * 0.05)
    ..quadraticBezierTo(r * 0.3, r * 0.42, 0, r * 0.45)
    ..quadraticBezierTo(-r * 0.3, r * 0.42, -r * 0.48, r * 0.05)
    ..close();
  k.blob(c, head, const Color(0xFFFF8A6A), redD);
  // 불빛 눈(주황 + 세로 동공)
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.24, -r * 0.08);
    final eye = Rect.fromCenter(center: at, width: r * 0.26, height: r * 0.24);
    k.fill.color = const Color(0xFFFFB02A);
    c
      ..drawOval(eye, k.fill)
      ..drawOval(eye, k.ink);
    k.fill.color = HdKit.inkColor;
    c
      ..drawOval(Rect.fromCenter(center: at, width: r * 0.06, height: r * 0.18), k.fill)
      ..drawLine(at + Offset(-s * r * 0.18, -r * 0.2), at + Offset(s * r * 0.14, -r * 0.1), k.ink);
  }
  // 입 + 송곳니, 콧구멍
  k
    ..mouth(
      c,
      Path()
        ..moveTo(-r * 0.24, r * 0.2)
        ..quadraticBezierTo(0, r * 0.12, r * 0.24, r * 0.2)
        ..quadraticBezierTo(0, r * 0.4 + (k.wave(t, 1, 1) + 1) * r * 0.03, -r * 0.24, r * 0.2)
        ..close(),
    )
    ..tooth(c, Offset(-r * 0.2, r * 0.17), r * 0.09, r * 0.12)
    ..tooth(c, Offset(r * 0.11, r * 0.17), r * 0.09, r * 0.12)
    ..spots(c, r, const [(-0.07, 0.1, 0.025), (0.07, 0.1, 0.025)], HdKit.inkColor);
  c.restore();
  k.spots(c, r, const [(0.3, 0.35, 0.03), (-0.1, 0.05, 0.03)], belly);
}

/// 목 앞쪽 배 비늘(노란 반달 줄).
void _scales(HdKit k, Canvas c, Path neck, double r) {
  k.fill.color = const Color(0xFFFFC46A);
  for (final m in neck.computeMetrics()) {
    for (var i = 1; i < 7; i++) {
      final tg = m.getTangentForOffset(m.length * i / 7);
      if (tg == null) continue;
      c.drawOval(Rect.fromCenter(center: tg.position, width: r * 0.26, height: r * 0.1), k.fill);
    }
  }
}

/// 몸이 물을 뚫은 자리의 흰 물 고리.
void _waterRing(HdKit k, Canvas c, Offset at, double w) {
  k.fill.color = const Color(0xCCE8F8FF);
  c.drawOval(Rect.fromCenter(center: at, width: w * 2, height: w * 0.45), k.fill);
  k.fill.color = const Color(0x553A8AD0);
  c.drawOval(Rect.fromCenter(center: at + Offset(0, w * 0.04), width: w * 1.5, height: w * 0.25), k.fill);
}

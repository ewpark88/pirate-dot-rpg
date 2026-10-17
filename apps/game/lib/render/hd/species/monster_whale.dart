import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 괴물 고래(대보스 td_boss:monster_whale): 작살이 박힌 회청색 거대 고래가 정면으로 떠오른다 — 지느러미를 퍼덕이고
/// 붉은 눈·흉터, 숨구멍에서 물줄기가 고리마다 솟는다.
const monsterWhale = HdSpecies(_monsterWhale, extent: 1.55, ground: 1.02);

void _monsterWhale(HdKit k, Canvas c, double r, double t) {
  const grey = Color(0xFF8AA6D8);
  const greyD = Color(0xFF34466E);
  final bob = k.wave(t, 1) * r * 0.04;
  // 꼬리(아래 뒤로 보이는 두 갈래)
  final flick = k.wave(t, 1, 1) * r * 0.06;
  for (final s in const [-1.0, 1.0]) {
    final fluke = Path()
      ..moveTo(0, r * 0.75)
      ..quadraticBezierTo(s * r * 0.35, r * 0.85 + flick, s * r * 0.6, r * 0.78 + flick)
      ..quadraticBezierTo(s * r * 0.4, r * 1.05, 0, r * 0.95)
      ..close();
    k.blob(c, fluke, grey, greyD, gloss: false);
  }
  // 가슴지느러미(퍼덕)
  for (final s in const [-1.0, 1.0]) {
    final flap = k.wave(t, 1, s * 0.5) * 0.25;
    c
      ..save()
      ..translate(s * r * 0.72, r * 0.15 + bob)
      ..rotate(s * (0.5 + flap));
    final fin = Path()..addOval(Rect.fromCenter(center: Offset(s * r * 0.3, 0), width: r * 0.7, height: r * 0.28));
    k.blob(c, fin, grey, greyD, gloss: false);
    c.restore();
  }
  c
    ..save()
    ..translate(0, bob);
  // 몸통(큰 물방울)
  final body = Path()
    ..moveTo(0, -r * 0.95)
    ..cubicTo(r * 0.75, -r * 0.95, r * 0.95, -r * 0.2, r * 0.75, r * 0.4)
    ..quadraticBezierTo(r * 0.45, r * 0.85, 0, r * 0.85)
    ..quadraticBezierTo(-r * 0.45, r * 0.85, -r * 0.75, r * 0.4)
    ..cubicTo(-r * 0.95, -r * 0.2, -r * 0.75, -r * 0.95, 0, -r * 0.95)
    ..close();
  k.blob(c, body, const Color(0xFFA8C0EC), greyD);
  // 흰 배(주름 줄)
  final belly = Path()
    ..moveTo(-r * 0.48, r * 0.1)
    ..quadraticBezierTo(0, -r * 0.05, r * 0.48, r * 0.1)
    ..quadraticBezierTo(r * 0.38, r * 0.8, 0, r * 0.8)
    ..quadraticBezierTo(-r * 0.38, r * 0.8, -r * 0.48, r * 0.1)
    ..close();
  k.blob(c, belly, const Color(0xFFF4F8FF), const Color(0xFFB8C8E0), gloss: false, line: 0.6);
  final w = k.ink.strokeWidth;
  k.ink.strokeWidth = w * 0.45;
  for (var i = 1; i <= 3; i++) {
    c.drawLine(Offset(-r * 0.3 + i * r * 0.15, r * 0.2), Offset(-r * 0.3 + i * r * 0.15, r * 0.7), k.ink);
  }
  k.ink.strokeWidth = w;
  // 따개비·흉터
  k.spots(c, r, const [(-0.55, -0.45, 0.06), (-0.62, -0.3, 0.04), (0.6, -0.1, 0.05)], const Color(0xFFDCE6F4));
  c
    ..drawLine(Offset(r * 0.3, -r * 0.7), Offset(r * 0.55, -r * 0.45), k.ink)
    ..drawLine(Offset(r * 0.36, -r * 0.5), Offset(r * 0.48, -r * 0.64), k.ink);
  // 작살 둘(나무 자루 + 쇠촉)
  for (final (x, y, a) in const [(-0.62, -0.05, -0.7), (0.55, 0.2, 0.6)]) {
    final at = Offset(x * r, y * r);
    final tip = at + Offset(a * r * 0.55, -r * 0.55);
    k
      ..limb(
        c,
        Path()
          ..moveTo(at.dx, at.dy)
          ..lineTo(tip.dx, tip.dy),
        const Color(0xFFB07A40),
        r * 0.06,
      )
      ..blob(
        c,
        Path()
          ..moveTo(tip.dx - r * 0.07, tip.dy + r * 0.02)
          ..lineTo(tip.dx + a * r * 0.12, tip.dy - r * 0.12)
          ..lineTo(tip.dx + r * 0.07, tip.dy + r * 0.04)
          ..close(),
        const Color(0xFFE0E6F0),
        const Color(0xFF8090A8),
        gloss: false,
        line: 0.6,
      );
  }
  // 붉은 눈(화남) + 큰 입(이빨 몇 개)
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.42, -r * 0.42);
    final eye = Rect.fromCenter(center: at, width: r * 0.28, height: r * 0.3);
    k.fill.color = const Color(0xFFFF4A3A);
    c
      ..drawOval(eye, k.fill)
      ..drawOval(eye, k.ink);
    k.fill.color = HdKit.inkColor;
    c.drawCircle(at + Offset(-s * r * 0.02, r * 0.02), r * 0.06, k.fill);
    k.fill.color = const Color(0xFFFFFFFF);
    c
      ..drawCircle(at + Offset(-r * 0.05, -r * 0.06), r * 0.035, k.fill)
      ..drawLine(at + Offset(-s * r * 0.2, -r * 0.25), at + Offset(s * r * 0.16, -r * 0.14), k.ink);
  }
  k.mouth(
    c,
    Path()
      ..moveTo(-r * 0.5, -r * 0.12)
      ..quadraticBezierTo(0, r * 0.02, r * 0.5, -r * 0.12)
      ..quadraticBezierTo(0, r * 0.12 + (k.wave(t, 1) + 1) * r * 0.03, -r * 0.5, -r * 0.12)
      ..close(),
  );
  for (final x in const [-0.36, -0.12, 0.12]) {
    k.tooth(c, Offset(x * r, -r * 0.08), r * 0.12, r * 0.09);
  }
  // 숨구멍 물줄기(고리 앞 절반에 솟고 사라짐)
  final spout = (k.wave(t, 1, -1.2) + 1) / 2;
  if (spout > 0.25) {
    k.fill.color = Color.fromRGBO(220, 244, 255, 0.85 * spout);
    for (final (dx, dy, s) in const [
      (0.0, -1.2, 0.12),
      (-0.14, -1.32, 0.08),
      (0.14, -1.32, 0.08),
      (0.0, -1.42, 0.07),
    ]) {
      c.drawCircle(Offset(dx * r, (dy + 0.1 * (1 - spout)) * r), s * r * spout, k.fill);
    }
  }
  c.restore();
}

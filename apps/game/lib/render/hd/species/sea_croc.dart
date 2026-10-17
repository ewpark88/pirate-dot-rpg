import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 바다 악어(대보스 td_boss:sea_croc): 물에서 상체를 내민 초록 악어 — 큰 턱이 딱딱 열리고 짧은 팔을 휘젓는다.
const seaCroc = HdSpecies(_seaCroc, extent: 1.45, ground: 0.95);

void _seaCroc(HdKit k, Canvas c, double r, double t) {
  const green = Color(0xFF6CD24A);
  const greenD = Color(0xFF2A7A2E);
  final bob = k.wave(t, 2) * r * 0.03;
  final jaw = (k.wave(t, 1) + 1) / 2; // 0 닫힘 ~ 1 벌림
  // 꼬리(뒤에서 오른쪽으로 휘어 나옴)
  final tail = Path()
    ..moveTo(r * 0.35, r * 0.7)
    ..quadraticBezierTo(r * 1.2, r * 0.75 + k.wave(t, 1, 1) * r * 0.1, r * 1.3, r * 0.2)
    ..quadraticBezierTo(r * 1.05, r * 0.55, r * 0.4, r * 0.45)
    ..close();
  k.blob(c, tail, green, greenD, gloss: false);
  // 팔(휘젓기)
  for (final s in const [-1.0, 1.0]) {
    final sw = k.wave(t, 2, s) * r * 0.08;
    final arm = Path()
      ..moveTo(s * r * 0.5, r * 0.2 + bob)
      ..quadraticBezierTo(s * r * 0.95, r * 0.1 + sw, s * r * 1.0, r * 0.45 + sw);
    k.limb(c, arm, greenD, r * 0.2);
    for (var f = -1; f <= 1; f++) {
      c.drawCircle(Offset(s * r * 1.0 + f * r * 0.06, r * 0.52 + sw), r * 0.035, k.ink);
    }
  }
  c
    ..save()
    ..translate(0, bob);
  // 몸통(배는 연노랑 줄무늬)
  final body = Path()
    ..moveTo(-r * 0.6, r * 0.85)
    ..cubicTo(-r * 0.75, r * 0.1, -r * 0.55, -r * 0.35, 0, -r * 0.35)
    ..cubicTo(r * 0.55, -r * 0.35, r * 0.75, r * 0.1, r * 0.6, r * 0.85)
    ..close();
  k.blob(c, body, green, greenD);
  final belly = Path()
    ..moveTo(-r * 0.32, r * 0.85)
    ..quadraticBezierTo(-r * 0.4, r * 0.05, 0, r * 0.0)
    ..quadraticBezierTo(r * 0.4, r * 0.05, r * 0.32, r * 0.85)
    ..close();
  k.blob(c, belly, const Color(0xFFFFF0A8), const Color(0xFFE0C060), gloss: false, line: 0.6);
  for (var i = 1; i <= 3; i++) {
    final y = r * (0.12 + i * 0.18);
    c.drawLine(Offset(-r * 0.3, y), Offset(r * 0.3, y), k.ink..strokeWidth *= 0.5);
    k.ink.strokeWidth *= 2;
  }
  // 아래턱(벌어지면 내려감) + 이빨
  final drop = r * 0.22 * jaw;
  final lower = Path()
    ..moveTo(-r * 0.55, -r * 0.45)
    ..quadraticBezierTo(-r * 0.6, -r * 0.05 + drop, 0, r * 0.0 + drop)
    ..quadraticBezierTo(r * 0.6, -r * 0.05 + drop, r * 0.55, -r * 0.45)
    ..close();
  k.mouth(c, lower);
  for (var i = 0; i < 4; i++) {
    k.tooth(c, Offset(-r * 0.38 + i * r * 0.2, -r * 0.08 + drop * 0.9), r * 0.13, -r * 0.14);
  }
  // 윗머리(긴 주둥이·콧구멍) + 윗니
  final head = Path()
    ..moveTo(-r * 0.6, -r * 0.42)
    ..cubicTo(-r * 0.7, -r * 1.25, r * 0.7, -r * 1.25, r * 0.6, -r * 0.42)
    ..quadraticBezierTo(0, -r * 0.3, -r * 0.6, -r * 0.42)
    ..close();
  for (var i = 0; i < 5; i++) {
    k.tooth(c, Offset(-r * 0.5 + i * r * 0.2, -r * 0.4), r * 0.13, r * 0.15);
  }
  k
    ..blob(c, head, const Color(0xFF8CE86A), greenD)
    ..spots(c, r, const [(-0.12, -0.55, 0.04), (0.12, -0.55, 0.04)], HdKit.inkColor)
    ..spots(c, r, const [(-0.35, -0.75, 0.07), (0.38, -0.68, 0.05), (0.0, -0.9, 0.06)], const Color(0x552A7A2E));
  // 눈(머리 위로 튀어나온 혹 위)
  for (final s in const [-1.0, 1.0]) {
    final bump = Path()
      ..addOval(Rect.fromCenter(center: Offset(s * r * 0.33, -r * 1.02), width: r * 0.42, height: r * 0.34));
    k
      ..blob(c, bump, green, greenD, gloss: false)
      ..eye(c, Offset(s * r * 0.33, -r * 1.04), r * 0.3, angry: true, look: -0.4);
  }
  // 등 돌기(머리 뒤 양옆)
  for (final s in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final y = r * (-0.2 + i * 0.25);
      final x = s * r * (0.66 - i * 0.02);
      final ridge = Path()
        ..moveTo(x, y - r * 0.08)
        ..lineTo(x + s * r * 0.14, y)
        ..lineTo(x, y + r * 0.08)
        ..close();
      k.blob(c, ridge, green, greenD, gloss: false, line: 0.6);
    }
  }
  c.restore();
}

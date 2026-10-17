import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 물범(td_enemy:seal — 빙하 · 단단함 · 수면): 넓고 낮은 통통한 회백 몸 + 회색 반점, 앞지느러미·뒤 꼬리지느러미, 수염,
/// 크고 촉촉한 느긋한 눈. 테 두껍게, 몸을 들썩이며 느리게.
const seal = HdSpecies(_seal, extent: 1.45);

void _seal(HdKit k, Canvas c, double r, double t) {
  final heave = k.wave(t, 1);
  final lift = heave * r * 0.05;
  // 꼬리지느러미(뒤, 오른쪽).
  k.tail(
    c,
    Offset(r * 0.95, r * 0.25),
    r * 0.45,
    -0.2 + heave * 0.12,
    const Color(0xFFC8D0DA),
    const Color(0xFF7A8696),
  );
  c
    ..save()
    ..translate(0, -lift);
  // 단단함: 넓고 낮은 몸 + 두꺼운 테.
  final body = Path()..addOval(Rect.fromCenter(center: Offset(r * 0.1, r * 0.15), width: r * 2.0, height: r * 1.0));
  final w = k.ink.strokeWidth;
  k.ink.strokeWidth = w * 1.4;
  k.blob(c, body, const Color(0xFFE8EEF4), const Color(0xFF8C98A8));
  k.ink.strokeWidth = w;
  k.spots(c, r, const [
    (0.3, -0.1, 0.07),
    (0.55, 0.15, 0.06),
    (0.1, 0.05, 0.05),
    (0.75, -0.05, 0.05),
  ], const Color(0xFF9AA6B6));
  // 머리(앞).
  final head = Path()
    ..addOval(Rect.fromCenter(center: Offset(-r * 0.75, -r * 0.08), width: r * 0.85, height: r * 0.75));
  k.blob(c, head, const Color(0xFFF0F4F8), const Color(0xFF9AA6B6));
  // 앞지느러미.
  final flipper = Path()
    ..moveTo(-r * 0.3, r * 0.35)
    ..quadraticBezierTo(-r * 0.45, r * 0.75 + lift, -r * 0.05, r * 0.7 + lift)
    ..close();
  k.blob(c, flipper, const Color(0xFFC8D0DA), const Color(0xFF7A8696), gloss: false, line: 0.7);
  // 코·수염.
  k.fill.color = const Color(0xFF2A2430);
  c.drawOval(Rect.fromCenter(center: Offset(-r * 1.08, -r * 0.02), width: r * 0.16, height: r * 0.11), k.fill);
  final whisker = k.ink.strokeWidth;
  k.ink.strokeWidth = whisker * 0.4;
  for (final dy in const [-0.06, 0.04, 0.14]) {
    c.drawLine(Offset(-r * 1.0, r * dy), Offset(-r * 1.35, r * (dy * 1.8)), k.ink);
  }
  k.ink.strokeWidth = whisker;
  k
    ..eye(c, Offset(-r * 0.78, -r * 0.2), r * 0.32, look: -1)
    ..cheeks(c, Offset(-r * 0.75, r * 0.08), 0, r * 0.2);
  c.restore();
}

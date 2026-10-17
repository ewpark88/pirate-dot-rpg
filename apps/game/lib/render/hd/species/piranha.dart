import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 피라냐(td_enemy:piranha): 화난 눈·큰 이빨 입, 꼬리를 탁탁 흔든다.
const piranha = HdSpecies(_piranha, extent: 1.45);

void _piranha(HdKit k, Canvas c, double r, double t) {
  const orange = Color(0xFFFF8A3A);
  const orangeD = Color(0xFFC8501A);
  final bob = k.wave(t, 2, 1) * r * 0.03;
  k.tail(c, Offset(r * 0.85, bob), r * 0.55, k.wave(t, 2) * 0.22, orange, orangeD);
  final fin = Path()
    ..moveTo(-r * 0.2, -r * 0.7 + bob)
    ..quadraticBezierTo(r * 0.15, -r * 1.15 + bob, r * 0.45, -r * 0.6 + bob)
    ..close();
  k.blob(c, fin, orange, orangeD, gloss: false);
  c
    ..save()
    ..translate(0, bob);
  final body = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: r * 1.9, height: r * 1.5));
  k.blob(c, body, const Color(0xFF7AA0FF), const Color(0xFF3A52C0));
  // 붉은 배
  final belly = Path()
    ..moveTo(-r * 0.9, r * 0.05)
    ..quadraticBezierTo(0, r * 0.95, r * 0.75, r * 0.2)
    ..quadraticBezierTo(0, r * 0.5, -r * 0.9, r * 0.05)
    ..close();
  k.fill.color = const Color(0xFFFF5A5A);
  c.drawPath(belly, k.fill);
  // 큰 입(한 고리에 한 번 딱딱) + 이빨
  final chomp = k.wave(t, 1) * r * 0.06;
  k.mouth(
    c,
    Path()
      ..moveTo(-r * 0.85, -r * 0.05)
      ..quadraticBezierTo(-r * 0.35, r * 0.55 + chomp, r * 0.1, r * 0.05)
      ..close(),
  );
  for (var i = 0; i < 4; i++) {
    k.tooth(c, Offset(-r * 0.72 + i * r * 0.2, -r * 0.02), r * 0.16, r * 0.16);
  }
  k.eye(c, Offset(-r * 0.2, -r * 0.35), r * 0.42, angry: true, look: -1);
  c.restore();
}

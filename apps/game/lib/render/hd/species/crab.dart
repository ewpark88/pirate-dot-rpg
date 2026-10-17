import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 게(td_enemy:crab) — '한 종 추가 방법' 예시(docs/specs/render-hd-style.md 6절). 집게를 번쩍 든 채 까딱·통통.
const crab = HdSpecies(_crab, extent: 1.35, ground: 0.7);

void _crab(HdKit k, Canvas c, double r, double t) {
  const red = Color(0xFFFF5A48);
  const redD = Color(0xFFC0281E);
  final bob = k.wave(t, 2) * r * 0.04; // 한 고리에 두 번 통통
  final claw = k.wave(t, 1) * 0.15; // 집게 까딱
  // 1) 뒤 부품: 다리 3쌍
  for (final s in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final y = r * (0.25 + i * 0.18) + bob * 0.5;
      final leg = Path()
        ..moveTo(s * r * 0.6, y)
        ..quadraticBezierTo(s * r * 1.05, y - r * 0.1, s * r * 1.1, y + r * 0.22 + k.wave(t, 2, i + s) * r * 0.03);
      k.limb(c, leg, redD, k.ink.strokeWidth * 1.1);
    }
  }
  // 2) 집게(몸 뒤에서 위로)
  for (final s in const [-1.0, 1.0]) {
    k.pincer(c, Offset(s * r * 0.85, -r * 0.55 + bob), r, s * (0.35 + claw), red, redD, open: 0.5 + claw * 3);
  }
  // 3) 몸통
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.15 + bob), width: r * 1.5, height: r * 1.05));
  k.blob(c, body, const Color(0xFFFF8A6A), redD);
  // 4) 얼굴: 눈자루 + 눈, 입, 볼
  for (final s in const [-1.0, 1.0]) {
    c.drawLine(Offset(s * r * 0.25, -r * 0.2 + bob), Offset(s * r * 0.3, -r * 0.48 + bob), k.ink);
    k.eye(c, Offset(s * r * 0.3, -r * 0.55 + bob), r * 0.34);
  }
  k
    ..smile(c, Offset(0, r * 0.25 + bob), r * 0.3)
    ..cheeks(c, Offset(0, r * 0.2 + bob), r * 0.45, r * 0.22);
}

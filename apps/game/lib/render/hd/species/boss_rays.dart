import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 번개 가오리 새끼(td_boss:thunder_ray_pup): 넓은 마름모 날개를 퍼덕이는 남색 가오리 — 날개 끝에 노란 번개가 튄다.
const thunderRayPup = HdSpecies(_thunderRayPup, extent: 1.5, ground: 0.9);

/// 번개 가오리(해역 보스 td_boss:thunder_ray): 다 자란 가오리 — 뿔 둘·송곳니, 날개 끝 번개가 더 자주 튄다.
const thunderRay = HdSpecies(_thunderRay, extent: 1.45, ground: 0.9);

void _thunderRayPup(HdKit k, Canvas c, double r, double t) => _ray(k, c, r, t, adult: false);

void _thunderRay(HdKit k, Canvas c, double r, double t) => _ray(k, c, r, t, adult: true);

void _ray(HdKit k, Canvas c, double r, double t, {required bool adult}) {
  const navyD = Color(0xFF26306E);
  final flap = k.wave(t, 1) * r * 0.12;
  // 꼬리 채찍
  k.limb(
    c,
    Path()
      ..moveTo(0, r * 0.4)
      ..quadraticBezierTo(k.wave(t, 1, 1) * r * 0.25, r * 0.9, 0, r * 1.3),
    navyD,
    r * 0.06,
  );
  // 마름모 몸(날개 끝이 퍼덕)
  final body = Path()
    ..moveTo(0, -r * 0.85)
    ..quadraticBezierTo(r * 0.5, -r * 0.55, r * 1.25, -r * 0.05 + flap)
    ..quadraticBezierTo(r * 0.6, r * 0.25, 0, r * 0.5)
    ..quadraticBezierTo(-r * 0.6, r * 0.25, -r * 1.25, -r * 0.05 + flap)
    ..quadraticBezierTo(-r * 0.5, -r * 0.55, 0, -r * 0.85)
    ..close();
  k
    ..blob(c, body, const Color(0xFF8A9AE8), navyD)
    ..spots(c, r, const [
      (-0.6, -0.1, 0.05),
      (0.6, -0.1, 0.05),
      (-0.35, 0.15, 0.04),
      (0.35, 0.15, 0.04),
    ], const Color(0xAAFFE45A));
  // 등 볼록(얼굴 자리)
  if (adult) {
    for (final sd in const [-1.0, 1.0]) {
      k.blob(
        c,
        Path()
          ..moveTo(sd * r * 0.12, -r * 0.5)
          ..quadraticBezierTo(sd * r * 0.3, -r * 0.75, sd * r * 0.22, -r * 0.88)
          ..quadraticBezierTo(sd * r * 0.2, -r * 0.65, sd * r * 0.02, -r * 0.52)
          ..close(),
        const Color(0xFFFFE45A),
        const Color(0xFFD8901A),
        gloss: false,
        line: 0.6,
      );
    }
  }
  final head = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.2), width: r * 0.8, height: r * 0.72));
  k.blob(c, head, const Color(0xFFA8B4F0), navyD);
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.18, -r * 0.3), r * 0.26, angry: true);
  }
  k
    ..mouth(
      c,
      Path()
        ..moveTo(-r * 0.12, -r * 0.02)
        ..quadraticBezierTo(0, -r * 0.06, r * 0.12, -r * 0.02)
        ..quadraticBezierTo(0, r * 0.1, -r * 0.12, -r * 0.02)
        ..close(),
    )
    ..cheeks(c, Offset(0, -r * 0.12), r * 0.3, adult ? 0 : r * 0.14);
  if (adult) {
    k
      ..tooth(c, Offset(-r * 0.1, -r * 0.03), r * 0.07, r * 0.08)
      ..tooth(c, Offset(r * 0.03, -r * 0.03), r * 0.07, r * 0.08);
  }
  // 날개 끝 번개(고리 후반에 번쩍, 다 자라면 더 자주)
  final zap = k.wave(t, adult ? 3 : 2, 1);
  if (zap > 0.2) {
    k.fill.color = Color.fromRGBO(255, 230, 80, (zap - 0.2) / 0.8);
    for (final s in const [-1.0, 1.0]) {
      final at = Offset(s * r * 1.25, -r * 0.05 + flap);
      c.drawPath(
        Path()
          ..moveTo(at.dx, at.dy - r * 0.28)
          ..lineTo(at.dx + s * r * 0.12, at.dy - r * 0.05)
          ..lineTo(at.dx + s * r * 0.02, at.dy - r * 0.05)
          ..lineTo(at.dx + s * r * 0.14, at.dy + r * 0.22)
          ..lineTo(at.dx - s * r * 0.06, at.dy - r * 0.02)
          ..lineTo(at.dx + s * r * 0.04, at.dy - r * 0.02)
          ..close(),
        k.fill,
      );
    }
  }
}

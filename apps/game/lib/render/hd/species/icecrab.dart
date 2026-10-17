import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 얼음게(td_enemy:icecrab — 빙하 · 분열 → 작은 것 2): 얼음 등딱지에 쪼개질 금 3줄(곧 깨질 듯 반짝), 고드름 집게.
const icecrab = HdSpecies(_icecrab, extent: 1.25, ground: 0.7);

/// 작은 얼음게(td_enemy:icecrab_small — 분열로 생긴 것): 같은 색 조금 밝게, 금 없음, 놀란 눈, 빠른 종종걸음.
/// 분열 규칙 '반 크기'는 칸이 맡는다(td_icecrab_small 칸 12단위 → 굽기가 이미 작게) — extent는 얼음게와 같게(S3).
const icecrabSmall = HdSpecies(_icecrabSmall, extent: 1.25, ground: 0.7);

void _icecrab(HdKit k, Canvas c, double r, double t) => _drawIceCrab(k, c, r, t, small: false);

void _icecrabSmall(HdKit k, Canvas c, double r, double t) => _drawIceCrab(k, c, r, t, small: true);

void _drawIceCrab(HdKit k, Canvas c, double r, double t, {required bool small}) {
  final light = small ? const Color(0xFFF4FCFF) : const Color(0xFFE2F4FF);
  const dark = Color(0xFF6FA8D8);
  const shellD = Color(0xFF3F78B0);
  // 작은 것은 종종걸음(고리에 네 번), 큰 것은 두 번.
  final bob = k.wave(t, small ? 4 : 2) * r * 0.04;
  final claw = k.wave(t, 1) * 0.15;
  for (final s in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final y = r * (0.25 + i * 0.18) + bob * 0.5;
      final leg = Path()
        ..moveTo(s * r * 0.6, y)
        ..quadraticBezierTo(s * r * 1.05, y - r * 0.1, s * r * 1.1, y + r * 0.22 + k.wave(t, 2, i + s) * r * 0.03);
      k.limb(c, leg, dark, k.ink.strokeWidth * 1.1);
    }
  }
  // 고드름 집게(얼음색).
  for (final s in const [-1.0, 1.0]) {
    k.pincer(
      c,
      Offset(s * r * 0.85, -r * 0.55 + bob),
      r * (small ? 0.85 : 1),
      s * (0.35 + claw),
      light,
      dark,
      open: 0.5 + claw * 3,
    );
  }
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.15 + bob), width: r * 1.5, height: r * 1.05));
  k.blob(c, body, light, shellD);
  if (!small) {
    // 분열 규칙: 쪼개질 금 3줄 — 금 끝이 고리에 한 번 반짝.
    final crack = Path()
      ..moveTo(-r * 0.45, -r * 0.2 + bob)
      ..lineTo(-r * 0.2, r * 0.05 + bob)
      ..lineTo(-r * 0.32, r * 0.35 + bob)
      ..moveTo(r * 0.05, -r * 0.3 + bob)
      ..lineTo(0, r * 0.12 + bob)
      ..lineTo(r * 0.12, r * 0.42 + bob)
      ..moveTo(r * 0.45, -r * 0.18 + bob)
      ..lineTo(r * 0.3, r * 0.1 + bob);
    final w = k.ink.strokeWidth;
    k.ink.strokeWidth = w * 0.6;
    c.drawPath(crack, k.ink);
    k.ink.strokeWidth = w;
    final glint = (k.wave(t, 1) + 1) * 0.5;
    k.fill.color = Color.fromRGBO(255, 255, 255, 0.4 + 0.6 * glint);
    c.drawCircle(Offset(-r * 0.2, r * 0.05 + bob), r * 0.06, k.fill);
  }
  for (final s in const [-1.0, 1.0]) {
    c.drawLine(Offset(s * r * 0.25, -r * 0.2 + bob), Offset(s * r * 0.3, -r * 0.48 + bob), k.ink);
    // 빙하 눈 규칙: 동그랗고 차분(작은 것은 크게 뜬 놀란 눈).
    k.eye(c, Offset(s * r * 0.3, -r * 0.55 + bob), r * (small ? 0.38 : 0.3));
  }
  k.cheeks(c, Offset(0, r * 0.2 + bob), r * 0.45, r * 0.22);
}

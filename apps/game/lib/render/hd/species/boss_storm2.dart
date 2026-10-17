import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 폭풍 독수리(td_boss:storm_eagle, 폭풍 순환 v2): 회색 큰 바다독수리 — 펄럭이는 날개 끝에 번개가 튄다.
const stormEagle = HdSpecies(_stormEagle, extent: 1.55, ground: 1.15);

/// 먹구름 고래(td_boss:cloud_whale): 등에 먹구름을 얹은 남색 고래, 구름에서 빗줄기가 떨어진다.
const cloudWhale = HdSpecies(_cloudWhale, extent: 1.5, ground: 1);

/// 번개 게(td_boss:thunder_crab): 노란 줄무늬 남색 게, 두 집게에 전기 구슬이 지직거린다.
const thunderCrab = HdSpecies(_thunderCrab, extent: 1.5, ground: 0.95);

final _line = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// 지그재그 작은 번개(노랑 + 흰 심).
void _spark(Canvas c, Offset from, Offset to, double r, int seed) {
  final p = Path()..moveTo(from.dx, from.dy);
  for (var k = 1; k <= 4; k++) {
    final q = Offset.lerp(from, to, k / 4)!;
    p.lineTo(q.dx + (k == 4 ? 0 : ((seed * 7 + k * 5) % 7 - 3) * r * 0.03), q.dy);
  }
  _line
    ..strokeWidth = r * 0.07
    ..color = const Color(0xFFFFE04A);
  c.drawPath(p, _line);
  _line
    ..strokeWidth = r * 0.03
    ..color = const Color(0xFFFFFFFF);
  c.drawPath(p, _line);
}

void _stormEagle(HdKit k, Canvas c, double r, double t) {
  const grey = Color(0xFFB8C0CC);
  const greyD = Color(0xFF4A5264);
  final flap = k.wave(t, 2) * 0.35;
  final bob = -k.wave(t, 2) * r * 0.05;
  for (final s in const [-1.0, 1.0]) {
    final tip = Offset(s * r * 1.35, -r * (0.35 + flap) + bob);
    final wing = Path()
      ..moveTo(s * r * 0.3, -r * 0.15 + bob)
      ..quadraticBezierTo(s * r * 0.9, -r * (0.75 + flap), tip.dx, tip.dy)
      ..quadraticBezierTo(s * r * 1.0, r * 0.05 + bob, s * r * 0.35, r * 0.25 + bob)
      ..close();
    k.blob(c, wing, grey, greyD);
    _spark(c, tip, tip + Offset(s * r * 0.15, r * 0.4), r, s > 0 ? 1 : 2);
  }
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.1 + bob), width: r * 0.85, height: r * 1.1));
  k.blob(c, body, const Color(0xFFD8DEE8), greyD);
  final head = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.6 + bob), width: r * 0.82, height: r * 0.74));
  k
    ..blob(c, head, const Color(0xFFFFFFFF), greyD)
    ..eye(c, Offset(-r * 0.17, -r * 0.68 + bob), r * 0.27, angry: true)
    ..eye(c, Offset(r * 0.17, -r * 0.68 + bob), r * 0.27, angry: true);
  // 노란 갈고리 부리
  final beak = Path()
    ..moveTo(-r * 0.1, -r * 0.45 + bob)
    ..lineTo(r * 0.1, -r * 0.45 + bob)
    ..quadraticBezierTo(r * 0.06, -r * 0.25 + bob, 0, -r * 0.2 + bob)
    ..quadraticBezierTo(-r * 0.06, -r * 0.25 + bob, -r * 0.1, -r * 0.45 + bob)
    ..close();
  k.blob(c, beak, const Color(0xFFFFD45A), const Color(0xFFC08A20), gloss: false);
}

void _cloudWhale(HdKit k, Canvas c, double r, double t) {
  const navy = Color(0xFF3A5A9A);
  const navyD = Color(0xFF1A2A50);
  final bob = k.wave(t, 1) * r * 0.04;
  k.tail(c, Offset(r * 0.9, r * 0.15 + bob), r * 0.5, k.wave(t, 1) * 0.3, navy, navyD);
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.15 + bob), width: r * 1.95, height: r * 1.15));
  k.blob(c, body, const Color(0xFF5A80C8), navyD);
  // 흰 배
  k.fill.color = const Color(0xFFDCE8F8);
  c.drawOval(Rect.fromCenter(center: Offset(-r * 0.15, r * 0.45 + bob), width: r * 1.1, height: r * 0.35), k.fill);
  k
    ..eye(c, Offset(-r * 0.55, r * 0.0 + bob), r * 0.28, angry: true)
    ..mouth(
      c,
      Path()
        ..moveTo(-r * 0.95, r * 0.25 + bob)
        ..quadraticBezierTo(-r * 0.6, r * 0.4 + bob, -r * 0.3, r * 0.28 + bob)
        ..lineTo(-r * 0.3, r * 0.33 + bob)
        ..quadraticBezierTo(-r * 0.6, r * 0.48 + bob, -r * 0.95, r * 0.3 + bob)
        ..close(),
    );
  // 등 위 먹구름(뭉게 3) + 빗줄기
  final drift = k.wave(t, 1, 1) * r * 0.06;
  for (final (x, y, s) in const [(-0.35, -0.7, 0.45), (0.1, -0.85, 0.55), (0.5, -0.68, 0.4)]) {
    final cloud = Path()..addOval(Rect.fromCircle(center: Offset(x * r + drift, y * r + bob), radius: s * r));
    k.blob(c, cloud, const Color(0xFF8A94AC), const Color(0xFF3A4258), gloss: false);
  }
  _line
    ..strokeWidth = r * 0.03
    ..color = const Color(0xCC9AD8FF);
  for (var i = 0; i < 6; i++) {
    final x = -r * 0.6 + i * r * 0.24 + drift;
    final y0 = -r * 0.35 + bob + ((t / HdKit.loopMs * 3 + i * 0.37) % 1) * r * 0.3;
    c.drawLine(Offset(x, y0), Offset(x - r * 0.05, y0 + r * 0.15), _line);
  }
  if (k.wave(t, 1, 2) > 0.85) _spark(c, Offset(r * 0.1 + drift, -r * 0.6 + bob), Offset(r * 0.2, -r * 0.2 + bob), r, 3);
}

void _thunderCrab(HdKit k, Canvas c, double r, double t) {
  const navy = Color(0xFF3A4A8A);
  const navyD = Color(0xFF1A2050);
  final bob = k.wave(t, 2) * r * 0.03;
  // 다리 3쌍
  for (final s in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final y = r * (0.15 + i * 0.18) + bob;
      k.limb(
        c,
        Path()
          ..moveTo(s * r * 0.55, y)
          ..quadraticBezierTo(s * r * 0.95, y - r * 0.1, s * r * (1.1 + k.wave(t, 2, i + s) * 0.04), y + r * 0.25),
        navyD,
        r * 0.09,
      );
    }
  }
  final shell = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.2 + bob), width: r * 1.5, height: r * 1.0));
  k.blob(c, shell, const Color(0xFF5A6AC0), navyD);
  // 노란 번개 줄무늬
  c
    ..save()
    ..clipPath(shell);
  k.fill.color = const Color(0xFFFFD84A);
  for (final x in const [-0.35, 0.05, 0.45]) {
    c.drawPath(
      Path()
        ..moveTo(x * r - r * 0.05, -r * 0.3 + bob)
        ..lineTo(x * r + r * 0.08, r * 0.15 + bob)
        ..lineTo(x * r - r * 0.02, r * 0.15 + bob)
        ..lineTo(x * r + r * 0.07, r * 0.7 + bob)
        ..lineTo(x * r - r * 0.12, r * 0.1 + bob)
        ..lineTo(x * r - r * 0.02, r * 0.1 + bob)
        ..close(),
      k.fill,
    );
  }
  c
    ..restore()
    ..drawPath(shell, k.ink);
  // 집게 + 전기 구슬
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.85, -r * 0.45 + bob);
    k
      ..limb(
        c,
        Path()
          ..moveTo(s * r * 0.45, r * 0.0 + bob)
          ..lineTo(at.dx, at.dy + r * 0.2),
        navy,
        r * 0.14,
      )
      ..pincer(c, at, r * 0.32, s * 0.4, const Color(0xFF6A7AD0), navyD, open: (k.wave(t, 2, s) + 1) / 2 * 0.5);
    final orb = at + Offset(0, -r * 0.32);
    final glow = 0.6 + 0.4 * k.wave(t, 4, s).abs();
    k.fill.color = Color.fromRGBO(255, 240, 120, 0.35 * glow);
    c.drawCircle(orb, r * 0.2 * glow, k.fill);
    k.fill.color = const Color(0xFFFFF6B0);
    c.drawCircle(orb, r * 0.09, k.fill);
    _spark(c, orb, orb + Offset(s * r * 0.2, -r * 0.2 * math.max(0.5, glow)), r, s > 0 ? 4 : 5);
  }
  k
    ..eye(c, Offset(-r * 0.2, -r * 0.2 + bob), r * 0.24, angry: true)
    ..eye(c, Offset(r * 0.2, -r * 0.2 + bob), r * 0.24, angry: true);
}

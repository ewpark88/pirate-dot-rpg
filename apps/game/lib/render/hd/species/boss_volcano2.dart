import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 마그마 골렘(td_boss:magma_golem, 화산 순환 v2): 금 간 검은 바위 몸 사이로 용암이 흐르는 거인 — 금이 숨 쉬듯 빛난다.
const magmaGolem = HdSpecies(_magmaGolem, extent: 1.5, ground: 1.05);

/// 불도롱뇽(td_boss:fire_salamander): 주황·검정 도롱뇽, 등에 불꽃 지느러미가 일렁인다.
const fireSalamander = HdSpecies(_fireSalamander, extent: 1.5, ground: 1);

/// 화산재 용(td_boss:ash_dragon): 재빛 날개·붉은 눈의 작은 용, 입가에 불티가 튄다.
const ashDragon = HdSpecies(_ashDragon, extent: 1.55, ground: 1.15);

final _line = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// 불꽃 혀 하나(아래 [base]에서 위로 [h]만큼, 일렁임 [sway]).
void _flame(HdKit k, Canvas c, Offset base, double w, double h, double sway) {
  final p = Path()
    ..moveTo(base.dx - w, base.dy)
    ..quadraticBezierTo(base.dx - w * 0.8 + sway, base.dy - h * 0.6, base.dx + sway, base.dy - h)
    ..quadraticBezierTo(base.dx + w * 0.8 + sway, base.dy - h * 0.6, base.dx + w, base.dy)
    ..close();
  k.blob(c, p, const Color(0xFFFFE07A), const Color(0xFFFF5A1A), gloss: false);
}

void _magmaGolem(HdKit k, Canvas c, double r, double t) {
  const rock = Color(0xFF4A4250);
  const rockD = Color(0xFF1A1420);
  final bob = k.wave(t, 1) * r * 0.03;
  final pulse = 0.6 + 0.4 * (k.wave(t, 1, 1) + 1) / 2;
  // 다리·팔
  for (final s in const [-1.0, 1.0]) {
    k
      ..blob(
        c,
        Path()
          ..addOval(Rect.fromCenter(center: Offset(s * r * 0.35, r * 0.6 + bob), width: r * 0.45, height: r * 0.35)),
        rock,
        rockD,
      )
      ..limb(
        c,
        Path()
          ..moveTo(s * r * 0.6, -r * 0.15 + bob)
          ..quadraticBezierTo(s * r * 1.0, r * 0.1 + bob, s * r * 0.9, r * 0.45 + bob),
        const Color(0xFF5A5262),
        r * 0.3,
      );
  }
  final body = Path()
    ..moveTo(-r * 0.7, -r * 0.4 + bob)
    ..lineTo(r * 0.65, -r * 0.5 + bob)
    ..lineTo(r * 0.75, r * 0.4 + bob)
    ..lineTo(-r * 0.75, r * 0.45 + bob)
    ..close();
  k.blob(c, body, const Color(0xFF6A6272), rockD);
  // 용암 금(빛나며 맥박)
  final cracks = [
    [const Offset(-0.4, -0.35), const Offset(-0.2, -0.05), const Offset(-0.35, 0.3)],
    [const Offset(0.3, -0.4), const Offset(0.15, 0), const Offset(0.4, 0.35)],
    [const Offset(-0.05, 0.1), const Offset(0.1, 0.4)],
  ];
  for (final cr in cracks) {
    final p = Path()..moveTo(cr.first.dx * r, cr.first.dy * r + bob);
    for (final q in cr.skip(1)) {
      p.lineTo(q.dx * r, q.dy * r + bob);
    }
    _line
      ..strokeWidth = r * 0.12
      ..color = Color.fromRGBO(255, 110, 30, 0.45 * pulse);
    c.drawPath(p, _line);
    _line
      ..strokeWidth = r * 0.05
      ..color = Color.fromRGBO(255, 220, 90, pulse);
    c.drawPath(p, _line);
  }
  // 머리(작은 바위) + 불타는 눈
  final head = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.65 + bob), width: r * 0.75, height: r * 0.55));
  k
    ..blob(c, head, rock, rockD)
    ..eye(c, Offset(-r * 0.15, -r * 0.68 + bob), r * 0.22, angry: true)
    ..eye(c, Offset(r * 0.15, -r * 0.68 + bob), r * 0.22, angry: true);
  _flame(k, c, Offset(0, -r * 0.9 + bob), r * 0.18, r * (0.35 + 0.1 * pulse), k.wave(t, 2) * r * 0.05);
}

void _fireSalamander(HdKit k, Canvas c, double r, double t) {
  const orange = Color(0xFFFF8A3A);
  const orangeD = Color(0xFF8A2A10);
  final wig = k.wave(t, 1);
  // 꼬리(S자로 흔들)
  final tail = Path()
    ..moveTo(r * 0.5, r * 0.1)
    ..cubicTo(r * 0.9, r * (0.1 + 0.3 * wig), r * 1.1, -r * (0.1 + 0.3 * wig), r * 1.35, r * 0.05);
  k.limb(c, tail, orange, r * 0.22);
  // 다리 4
  for (final (x, s) in const [(-0.45, -1.0), (0.35, -1.0), (-0.45, 1.0), (0.35, 1.0)]) {
    k.limb(
      c,
      Path()
        ..moveTo(x * r, s * r * 0.2)
        ..lineTo(x * r + s * r * 0.08 * wig, s * r * 0.55),
      orangeD,
      r * 0.14,
    );
  }
  final body = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: r * 1.4, height: r * 0.7));
  // 몸 + 검은 점무늬
  k
    ..blob(c, body, orange, orangeD)
    ..spots(c, r, const [
      (-0.2, -0.1, 0.07),
      (0.2, 0.05, 0.08),
      (0.4, -0.12, 0.05),
      (-0.45, 0.1, 0.05),
    ], const Color(0xFF2A1410));
  // 등 불꽃 지느러미(일렁임)
  for (var i = 0; i < 4; i++) {
    final x = (-0.35 + i * 0.25) * r;
    _flame(
      k,
      c,
      Offset(x, -r * 0.28),
      r * 0.1,
      r * (0.35 + 0.1 * math.sin(t / 90 + i)),
      k.wave(t, 2, i * 1.0) * r * 0.05,
    );
  }
  // 머리
  final head = Path()..addOval(Rect.fromCenter(center: Offset(-r * 0.85, -r * 0.05), width: r * 0.7, height: r * 0.55));
  k
    ..blob(c, head, const Color(0xFFFFA05A), orangeD)
    ..eye(c, Offset(-r * 0.95, -r * 0.15), r * 0.22, angry: true)
    ..eye(c, Offset(-r * 0.72, -r * 0.18), r * 0.18, angry: true);
}

void _ashDragon(HdKit k, Canvas c, double r, double t) {
  const ash = Color(0xFF7A7484);
  const ashD = Color(0xFF2A2430);
  final flap = k.wave(t, 2) * 0.3;
  final bob = -k.wave(t, 2) * r * 0.05;
  // 날개(박쥐 날개 꼴)
  for (final s in const [-1.0, 1.0]) {
    final w = Path()
      ..moveTo(s * r * 0.25, -r * 0.1 + bob)
      ..lineTo(s * r * 1.3, -r * (0.75 + flap) + bob)
      ..lineTo(s * r * 1.2, -r * (0.2 + flap * 0.5) + bob)
      ..lineTo(s * r * 0.95, -r * (0.35 + flap * 0.6) + bob)
      ..lineTo(s * r * 0.8, r * 0.05 + bob)
      ..lineTo(s * r * 0.5, -r * 0.05 + bob)
      ..lineTo(s * r * 0.35, r * 0.2 + bob)
      ..close();
    k.blob(c, w, const Color(0xFF9A94A4), ashD);
  }
  k.tail(c, Offset(0, r * 0.65 + bob), r * 0.4, math.pi / 2 + k.wave(t, 1) * 0.3, ash, ashD);
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.2 + bob), width: r * 0.8, height: r * 0.95));
  k.blob(c, body, ash, ashD);
  // 배 비늘(밝은 띠)
  k.fill.color = const Color(0xFFD8C8B0);
  c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.3 + bob), width: r * 0.4, height: r * 0.6), k.fill);
  final head = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.45 + bob), width: r * 0.72, height: r * 0.6));
  k.blob(c, head, const Color(0xFF8A8494), ashD);
  // 뿔 두 개
  for (final s in const [-1.0, 1.0]) {
    k.blob(
      c,
      Path()
        ..moveTo(s * r * 0.15, -r * 0.7 + bob)
        ..lineTo(s * r * 0.35, -r * 1.0 + bob)
        ..lineTo(s * r * 0.3, -r * 0.65 + bob)
        ..close(),
      const Color(0xFFE8DCC8),
      ashD,
      gloss: false,
    );
  }
  k
    ..eye(c, Offset(-r * 0.15, -r * 0.5 + bob), r * 0.22, angry: true)
    ..eye(c, Offset(r * 0.15, -r * 0.5 + bob), r * 0.22, angry: true);
  // 입가 불티
  k.fill.color = const Color(0xFFFF8A2A);
  for (var i = 0; i < 4; i++) {
    final u = (t / HdKit.loopMs * 2 + i / 4) % 1;
    c.drawCircle(Offset((i - 1.5) * r * 0.08, -r * 0.2 - u * r * 0.25 + bob), r * 0.035 * (1 - u), k.fill);
  }
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 산호 골렘(td_boss:coral_golem, 산호 순환 v2): 등에 분홍 산호가 솟은 둥근 돌거북 — 작은 물고기 둘이 산호 사이를 돈다.
const coralGolem = HdSpecies(_coralGolem, extent: 1.5, ground: 1);

/// 흰동가리 왕(td_boss:clown_king): 금관 쓴 주황·흰 줄무늬 큰 물고기, 말미잘 망토가 하늘거린다.
const clownKing = HdSpecies(_clownKing, extent: 1.5, ground: 1.05);

/// 진주 조개(td_boss:pearl_clam): 입을 여닫는 거대 조개, 안에서 빛나는 진주가 눈처럼 깜빡인다.
const pearlClam = HdSpecies(_pearlClam, extent: 1.45, ground: 0.95);

final _line = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

void _coralGolem(HdKit k, Canvas c, double r, double t) {
  const rock = Color(0xFF9AA0B4);
  const rockD = Color(0xFF4A4E64);
  final bob = k.wave(t, 1) * r * 0.03;
  // 발 4개
  for (final (x, y) in const [(-0.7, 0.45), (0.7, 0.45), (-0.45, 0.7), (0.45, 0.7)]) {
    k.blob(
      c,
      Path()..addOval(Rect.fromCenter(center: Offset(x * r, y * r + bob), width: r * 0.42, height: r * 0.32)),
      rock,
      rockD,
    );
  }
  // 등딱지(돌) + 금
  final shell = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.1 + bob), width: r * 1.8, height: r * 1.25));
  k.blob(c, shell, const Color(0xFFB8BDCC), rockD);
  _line
    ..strokeWidth = r * 0.03
    ..color = rockD;
  c
    ..drawLine(Offset(-r * 0.5, -r * 0.05 + bob), Offset(-r * 0.2, r * 0.25 + bob), _line)
    ..drawLine(Offset(r * 0.3, -r * 0.1 + bob), Offset(r * 0.55, r * 0.3 + bob), _line);
  // 산호 가지(분홍, 흔들)
  for (final (x, h, s) in const [(-0.45, 0.75, 1.0), (0.0, 0.95, -1.0), (0.42, 0.7, 1.0)]) {
    final sway = k.wave(t, 1, x * 3) * r * 0.05 * s;
    final base = Offset(x * r, -r * 0.35 + bob);
    final top = base + Offset(sway, -h * r);
    final branch = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(base.dx + sway, (base.dy + top.dy) / 2, top.dx, top.dy);
    k
      ..limb(c, branch, const Color(0xFFFF7FA8), r * 0.13)
      ..limb(
        c,
        Path()
          ..moveTo((base.dx + top.dx) / 2, (base.dy + top.dy) / 2)
          ..lineTo((base.dx + top.dx) / 2 + r * 0.2 * s, (base.dy + top.dy) / 2 - r * 0.22),
        const Color(0xFFFF9AC0),
        r * 0.09,
      );
    k.fill.color = const Color(0xFFFFD0E2);
    c.drawCircle(top, r * 0.07, k.fill);
  }
  // 산호 사이를 도는 작은 물고기 둘
  for (var i = 0; i < 2; i++) {
    final a = 2 * math.pi * (t / HdKit.loopMs + i / 2);
    final p = Offset(math.cos(a) * r * 0.7, -r * 0.7 + math.sin(a) * r * 0.2 + bob);
    k.blob(
      c,
      Path()..addOval(Rect.fromCenter(center: p, width: r * 0.34, height: r * 0.2)),
      const Color(0xFFFFD45A),
      const Color(0xFFE08A20),
      gloss: false,
    );
  }
  // 머리(앞) + 눈
  final head = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.7 + bob), width: r * 0.8, height: r * 0.55));
  k
    ..blob(c, head, rock, rockD)
    ..eye(c, Offset(-r * 0.17, r * 0.65 + bob), r * 0.24, angry: true)
    ..eye(c, Offset(r * 0.17, r * 0.65 + bob), r * 0.24, angry: true);
}

void _clownKing(HdKit k, Canvas c, double r, double t) {
  const orange = Color(0xFFFF8A2A);
  const orangeD = Color(0xFFB04A10);
  final bob = k.wave(t, 1) * r * 0.05;
  // 말미잘 망토(뒤, 보라 촉수가 하늘거림)
  for (var i = 0; i < 7; i++) {
    final x = (i - 3) * r * 0.22;
    final sway = k.wave(t, 1, i * 0.8) * r * 0.08;
    k.limb(
      c,
      Path()
        ..moveTo(x, r * 0.1 + bob)
        ..quadraticBezierTo(x + sway, r * 0.6, x + sway * 1.6, r * 0.95),
      const Color(0xFFB98CFF),
      r * 0.12,
    );
  }
  k.tail(c, Offset(r * 0.8, r * 0.05 + bob), r * 0.45, k.wave(t, 2) * 0.3, orange, orangeD);
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, bob), width: r * 1.75, height: r * 1.2));
  k.blob(c, body, const Color(0xFFFFA04A), orangeD);
  // 흰 줄무늬 3줄(검은 테)
  c
    ..save()
    ..clipPath(body);
  for (final x in const [-0.45, 0.05, 0.55]) {
    final band = Rect.fromCenter(center: Offset(x * r, bob), width: r * 0.22, height: r * 1.4);
    k.fill.color = const Color(0xFFFFFFFF);
    c.drawRect(band, k.fill);
    _line
      ..strokeWidth = r * 0.035
      ..color = HdKit.inkColor;
    c
      ..drawLine(band.topLeft, band.bottomLeft, _line)
      ..drawLine(band.topRight, band.bottomRight, _line);
  }
  c
    ..restore()
    ..drawPath(body, k.ink);
  k
    ..eye(c, Offset(-r * 0.55, -r * 0.12 + bob), r * 0.34, angry: true, look: -0.5)
    ..mouth(
      c,
      Path()..addOval(Rect.fromCenter(center: Offset(-r * 0.8, r * 0.15 + bob), width: r * 0.16, height: r * 0.12)),
    )
    ..crown(c, Offset(-r * 0.2, -r * 0.62 + bob), r * 0.55);
}

void _pearlClam(HdKit k, Canvas c, double r, double t) {
  const shell = Color(0xFFF2D9F0);
  const shellD = Color(0xFF9A6AA8);
  final open = (k.wave(t, 1) + 1) / 2; // 0 닫힘 ~ 1 열림
  // 아래 껍데기
  final lower = Path()
    ..moveTo(-r * 1.1, 0)
    ..quadraticBezierTo(-r * 1.0, r * 0.8, 0, r * 0.85)
    ..quadraticBezierTo(r * 1.0, r * 0.8, r * 1.1, 0)
    ..close();
  k.blob(c, lower, shell, shellD);
  // 안쪽 + 진주(눈)
  final inner = Path()
    ..addOval(Rect.fromCenter(center: Offset(0, -r * 0.05), width: r * 1.9, height: r * (0.2 + 0.5 * open)));
  k.fill.color = const Color(0xFF6A3A7A);
  c.drawPath(inner, k.fill);
  final glow = 0.5 + 0.5 * open;
  k.fill.color = Color.fromRGBO(255, 240, 255, 0.35 * glow);
  c.drawCircle(Offset(0, -r * 0.08), r * 0.42 * glow, k.fill);
  k
    ..blob(
      c,
      Path()..addOval(Rect.fromCircle(center: Offset(0, -r * 0.08), radius: r * 0.32)),
      const Color(0xFFFFFFFF),
      const Color(0xFFD8B8E8),
    )
    ..eye(c, Offset(0, -r * 0.08), r * 0.34 * (0.6 + 0.4 * open), angry: true);
  // 위 껍데기(열림만큼 들림) + 부채 골
  c
    ..save()
    ..translate(0, -r * 0.35 * open);
  final upper = Path()
    ..moveTo(-r * 1.1, 0)
    ..quadraticBezierTo(-r * 1.0, -r * 0.9, 0, -r * 0.95)
    ..quadraticBezierTo(r * 1.0, -r * 0.9, r * 1.1, 0)
    ..close();
  k.blob(c, upper, const Color(0xFFFFE8FA), shellD);
  _line
    ..strokeWidth = r * 0.03
    ..color = shellD;
  for (var i = -3; i <= 3; i++) {
    c.drawLine(Offset(i * r * 0.05, -r * 0.05), Offset(i * r * 0.3, -r * 0.8 + (i.abs() * r * 0.06)), _line);
  }
  c.restore();
}

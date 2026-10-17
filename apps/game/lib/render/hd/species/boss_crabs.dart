import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 얼음 게 대장(td_boss:icecrab_chief): 금관 쓴 하늘색 게 — 커다란 얼음 집게를 번쩍 들어 딱딱, 등에 고드름.
const icecrabChief = HdSpecies(_icecrabChief, extent: 1.45);

/// 소라게(td_boss:hermit_conch): 분홍 소라 껍데기를 진 게 — 껍데기에서 눈과 집게만 내밀고 들썩.
const hermitConch = HdSpecies(_hermitConch, extent: 1.45, ground: 0.85);

void _icecrabChief(HdKit k, Canvas c, double r, double t) {
  const ice = Color(0xFF9AD8FF);
  const iceD = Color(0xFF2A6AC0);
  final bob = k.wave(t, 2) * r * 0.035;
  final claw = k.wave(t, 1) * 0.18;
  _legs(k, c, r, t, iceD, bob);
  for (final s in const [-1.0, 1.0]) {
    k.pincer(
      c,
      Offset(s * r * 0.82, -r * 0.45 + bob),
      r * 1.25,
      s * (0.3 + claw),
      const Color(0xFFDDF4FF),
      iceD,
      open: 0.5 + claw * 2.5,
    );
  }
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.2 + bob), width: r * 1.6, height: r * 1.05));
  k.blob(c, body, const Color(0xFFC8ECFF), iceD);
  // 등 고드름
  for (final x in const [-0.45, -0.15, 0.15, 0.45]) {
    final p = Path()
      ..moveTo(x * r - r * 0.08, -r * 0.2 + bob)
      ..lineTo(x * r, -r * (0.42 + (x.abs() < 0.2 ? 0.08 : 0)) + bob)
      ..lineTo(x * r + r * 0.08, -r * 0.2 + bob)
      ..close();
    k.blob(c, p, const Color(0xFFFFFFFF), ice, gloss: false, line: 0.55);
  }
  _face(k, c, r, bob, angry: true);
  k.crown(c, Offset(0, -r * 0.88 + bob), r * 0.5);
}

void _hermitConch(HdKit k, Canvas c, double r, double t) {
  const red = Color(0xFFFF6A5A);
  const redD = Color(0xFFB02A2A);
  final bob = k.wave(t, 2) * r * 0.04;
  _legs(k, c, r, t, redD, bob);
  // 소라 껍데기(나선) — 몸 대신
  final shell = Path()
    ..moveTo(-r * 0.85, r * 0.55 + bob)
    ..cubicTo(-r * 1.05, -r * 0.4, -r * 0.3, -r * 1.05, r * 0.25, -r * 0.9 + bob)
    ..cubicTo(r * 0.9, -r * 0.7, r * 1.0, r * 0.1, r * 0.75, r * 0.55 + bob)
    ..quadraticBezierTo(0, r * 0.8, -r * 0.85, r * 0.55 + bob)
    ..close();
  k.blob(c, shell, const Color(0xFFFFC8E0), const Color(0xFFD0508A));
  // 나선 줄 + 가시
  final w = k.ink.strokeWidth;
  k.ink.strokeWidth = w * 0.55;
  final spiral = Path();
  for (var i = 0; i <= 40; i++) {
    final a = i / 40 * math.pi * 3.2;
    final rr = r * (0.08 + 0.55 * i / 40);
    final p = Offset(r * 0.05 + math.cos(a) * rr, -r * 0.15 + bob + math.sin(a) * rr * 0.8);
    i == 0 ? spiral.moveTo(p.dx, p.dy) : spiral.lineTo(p.dx, p.dy);
  }
  c.drawPath(spiral, k.ink);
  k.ink.strokeWidth = w;
  for (final (x, y) in const [(-0.75, -0.25), (-0.45, -0.75), (0.2, -0.95), (0.75, -0.55), (0.88, 0.1)]) {
    final at = Offset(x * r, y * r + bob);
    final out = at / at.distance;
    k.blob(
      c,
      Path()
        ..moveTo(at.dx - out.dy * r * 0.07, at.dy + out.dx * r * 0.07)
        ..lineTo(at.dx + out.dx * r * 0.18, at.dy + out.dy * r * 0.18)
        ..lineTo(at.dx + out.dy * r * 0.07, at.dy - out.dx * r * 0.07)
        ..close(),
      const Color(0xFFFFF0F6),
      const Color(0xFFE080B0),
      gloss: false,
      line: 0.55,
    );
  }
  // 껍데기 입구에서 내민 얼굴·집게
  final hole = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.42 + bob), width: r * 1.0, height: r * 0.42));
  k.fill.color = const Color(0xFF6A1A3A);
  c
    ..drawPath(hole, k.fill)
    ..drawPath(hole, k.ink);
  final claw = k.wave(t, 1) * 0.2;
  for (final s in const [-1.0, 1.0]) {
    k.pincer(c, Offset(s * r * 0.62, r * 0.48 + bob), r * 0.75, s * (1.35 + claw), red, redD, open: 0.4 + claw * 2);
  }
  for (final s in const [-1.0, 1.0]) {
    c.drawLine(Offset(s * r * 0.12, r * 0.4 + bob), Offset(s * r * 0.18, r * 0.12 + bob), k.ink);
    k.eye(c, Offset(s * r * 0.18, r * 0.06 + bob), r * 0.26, angry: true, look: -0.2);
  }
}

/// 다리 3쌍(뒤).
void _legs(HdKit k, Canvas c, double r, double t, Color color, double bob) {
  for (final s in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final y = r * (0.3 + i * 0.17) + bob * 0.5;
      final leg = Path()
        ..moveTo(s * r * 0.6, y)
        ..quadraticBezierTo(s * r * 1.08, y - r * 0.12, s * r * 1.15, y + r * 0.24 + k.wave(t, 2, i + s) * r * 0.03);
      k.limb(c, leg, color, r * 0.11);
    }
  }
}

/// 게 얼굴(눈자루 + 눈 + 입).
void _face(HdKit k, Canvas c, double r, double bob, {required bool angry}) {
  for (final s in const [-1.0, 1.0]) {
    c.drawLine(Offset(s * r * 0.24, -r * 0.15 + bob), Offset(s * r * 0.3, -r * 0.45 + bob), k.ink);
    k.eye(c, Offset(s * r * 0.3, -r * 0.52 + bob), r * 0.32, angry: angry, look: -0.3);
  }
  k
    ..mouth(
      c,
      Path()
        ..moveTo(-r * 0.2, r * 0.22 + bob)
        ..quadraticBezierTo(0, r * 0.42 + bob, r * 0.2, r * 0.22 + bob)
        ..close(),
    )
    ..tooth(c, Offset(-r * 0.14, r * 0.22 + bob), r * 0.1, r * 0.08)
    ..tooth(c, Offset(r * 0.04, r * 0.22 + bob), r * 0.1, r * 0.08);
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 심연의 눈(td_boss:abyss_eye, 심연 순환 v2): 보라로 빛나는 거대 외눈 — 둘레 촉수 6개가 꿈틀댄다.
const abyssEye = HdSpecies(_abyssEye, extent: 1.5, ground: 1.1);

/// 등불 장어(td_boss:lantern_eel): 머리에 등불 달린 검은 장어, 몸 따라 청록 발광 점이 흐른다.
const lanternEel = HdSpecies(_lanternEel, extent: 1.55, ground: 1);

/// 해골 상어(td_boss:bone_shark): 뼈만 남은 상어 — 갈비뼈 사이로 청록 빛, 이빨 가득한 턱.
const boneShark = HdSpecies(_boneShark, extent: 1.5, ground: 1);

final _line = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

void _abyssEye(HdKit k, Canvas c, double r, double t) {
  const purple = Color(0xFF6A3A9A);
  const purpleD = Color(0xFF2A1040);
  final bob = k.wave(t, 1) * r * 0.05;
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3 + math.pi / 6;
    final base = Offset(math.cos(a) * r * 0.55, math.sin(a) * r * 0.5 + bob);
    k.tentacle(c, base, a, r * 0.6, k.wave(t, 1, i * 1.0) * 0.5, purple, r * 0.16);
  }
  // 발광 둘레
  final glow = 0.6 + 0.4 * (k.wave(t, 1, 2) + 1) / 2;
  k.fill.color = Color.fromRGBO(190, 120, 255, 0.3 * glow);
  c.drawCircle(Offset(0, bob), r * 0.95 * glow, k.fill);
  final ball = Path()..addOval(Rect.fromCircle(center: Offset(0, bob), radius: r * 0.7));
  k.blob(c, ball, const Color(0xFFF4ECFF), purpleD);
  // 핏줄
  _line
    ..strokeWidth = r * 0.025
    ..color = const Color(0xAAD05A8A);
  for (var i = 0; i < 5; i++) {
    final a = i * 1.25 + 0.3;
    c.drawLine(
      Offset(math.cos(a) * r * 0.62, math.sin(a) * r * 0.62 + bob),
      Offset(math.cos(a + 0.2) * r * 0.4, math.sin(a + 0.2) * r * 0.4 + bob),
      _line,
    );
  }
  k.eye(c, Offset(0, bob), r * 0.75, angry: true);
}

void _lanternEel(HdKit k, Canvas c, double r, double t) {
  const dark = Color(0xFF2A3040);
  const darkD = Color(0xFF0E1018);
  // S자 몸(굵은 선)
  final pts = <Offset>[];
  for (var i = 0; i <= 10; i++) {
    final u = i / 10;
    pts.add(Offset(-r * 0.6 + u * r * 1.9, math.sin(u * 5 + t / 120) * r * 0.25 * u));
  }
  final body = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final p in pts.skip(1)) {
    body.lineTo(p.dx, p.dy);
  }
  k.limb(c, body, const Color(0xFF3A4458), r * 0.42);
  // 발광 점(몸 따라 흐름)
  for (var i = 0; i < 8; i++) {
    final u = (i / 8 + t / HdKit.loopMs) % 1;
    final p = pts[(u * 10).floor().clamp(0, 9)];
    final pulse = 0.5 + 0.5 * math.sin(t / 100 + i);
    k.fill.color = Color.fromRGBO(90, 240, 220, 0.4 * pulse);
    c.drawCircle(p, r * 0.1, k.fill);
    k.fill.color = Color.fromRGBO(210, 255, 250, pulse);
    c.drawCircle(p, r * 0.04, k.fill);
  }
  // 머리 + 등불
  final head = Path()..addOval(Rect.fromCenter(center: Offset(-r * 0.7, 0), width: r * 0.75, height: r * 0.6));
  k.blob(c, head, const Color(0xFF4A5468), darkD);
  final stalk = Path()
    ..moveTo(-r * 0.75, -r * 0.25)
    ..quadraticBezierTo(-r * 0.8, -r * 0.8, -r * 1.15, -r * 0.75 + k.wave(t, 1) * r * 0.05);
  k.limb(c, stalk, dark, r * 0.05);
  final lamp = Offset(-r * 1.15, -r * 0.75 + k.wave(t, 1) * r * 0.05);
  final glow = 0.6 + 0.4 * (k.wave(t, 2) + 1) / 2;
  k.fill.color = Color.fromRGBO(255, 230, 120, 0.35 * glow);
  c.drawCircle(lamp, r * 0.3 * glow, k.fill);
  k
    ..blob(
      c,
      Path()..addOval(Rect.fromCircle(center: lamp, radius: r * 0.13)),
      const Color(0xFFFFFAD0),
      const Color(0xFFE0A030),
    )
    ..eye(c, Offset(-r * 0.78, -r * 0.05), r * 0.24, angry: true)
    ..mouth(
      c,
      Path()
        ..moveTo(-r * 1.05, r * 0.1)
        ..lineTo(-r * 0.6, r * 0.15)
        ..lineTo(-r * 1.0, r * 0.2)
        ..close(),
    );
}

void _boneShark(HdKit k, Canvas c, double r, double t) {
  const bone = Color(0xFFF4F0E4);
  const boneD = Color(0xFF8A8270);
  final sway = k.wave(t, 1) * 0.15;
  // 등뼈 + 갈비뼈(사이로 청록 빛)
  final glow = 0.6 + 0.4 * (k.wave(t, 1, 1) + 1) / 2;
  k.fill.color = Color.fromRGBO(90, 240, 220, 0.3 * glow);
  c.drawOval(Rect.fromCenter(center: Offset(r * 0.15, r * 0.05), width: r * 1.2, height: r * 0.6), k.fill);
  k.limb(
    c,
    Path()
      ..moveTo(-r * 0.4, -r * 0.05)
      ..quadraticBezierTo(r * 0.4, -r * 0.2 + sway * r, r * 1.0, -r * 0.05),
    bone,
    r * 0.1,
  );
  for (var i = 0; i < 5; i++) {
    final x = -r * 0.2 + i * r * 0.25;
    k.limb(
      c,
      Path()
        ..moveTo(x, -r * 0.12)
        ..quadraticBezierTo(x + r * 0.1, r * 0.15, x - r * 0.02, r * 0.35),
      bone,
      r * 0.07,
    );
  }
  // 꼬리 뼈(갈래)
  for (final s in const [-1.0, 1.0]) {
    k.limb(
      c,
      Path()
        ..moveTo(r * 1.0, -r * 0.05)
        ..lineTo(r * 1.35, s * r * 0.35 + sway * r),
      bone,
      r * 0.08,
    );
  }
  // 등지느러미 뼈
  k.limb(
    c,
    Path()
      ..moveTo(r * 0.2, -r * 0.18)
      ..lineTo(r * 0.35, -r * 0.6),
    bone,
    r * 0.07,
  );
  // 해골 머리 + 턱
  final skull = Path()
    ..moveTo(-r * 1.15, -r * 0.05)
    ..quadraticBezierTo(-r * 0.9, -r * 0.5, -r * 0.35, -r * 0.3)
    ..quadraticBezierTo(-r * 0.25, 0, -r * 0.4, r * 0.05)
    ..close();
  k.blob(c, skull, bone, boneD);
  final open = (k.wave(t, 1, 0.5) + 1) / 2;
  final jaw = Path()
    ..moveTo(-r * 1.1, r * (0.02 + 0.1 * open))
    ..quadraticBezierTo(-r * 0.8, r * (0.35 + 0.1 * open), -r * 0.4, r * 0.1)
    ..close();
  k.blob(c, jaw, const Color(0xFFE8E0D0), boneD, gloss: false);
  for (var i = 0; i < 5; i++) {
    k.tooth(c, Offset(-r * 1.0 + i * r * 0.13, -r * 0.02), r * 0.08, r * 0.1);
  }
  // 눈구멍 속 청록 불
  k.fill.color = HdKit.inkColor;
  c.drawOval(Rect.fromCenter(center: Offset(-r * 0.68, -r * 0.2), width: r * 0.22, height: r * 0.2), k.fill);
  k.fill.color = Color.fromRGBO(120, 255, 230, glow);
  c.drawCircle(Offset(-r * 0.68, -r * 0.2), r * (k.mood == HdMood.windup ? 0.07 : 0.05), k.fill);
}

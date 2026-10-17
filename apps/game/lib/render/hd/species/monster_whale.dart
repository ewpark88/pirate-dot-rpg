import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_v2.dart';

/// 괴물 고래(대보스 td_boss:monster_whale): 작살이 박힌 회청색 거대 고래가 정면으로 떠오른다 — 지느러미를 퍼덕이고
/// 붉은 눈·흉터, 숨구멍에서 물줄기가 고리마다 솟는다. HD v2: 림 라이트·이중 광택, 표정: 평소 / 공격 예고(입 활짝·
/// 붉은 눈·물줄기 크게 계속) / 쓰러짐(배를 드러내며 기우뚱·소용돌이 눈·별).
const monsterWhale = HdSpecies(_monsterWhale, extent: 1.55, ground: 1.02);

/// 용암 고래(해역 보스 td_boss:lava_whale): 같은 고래 몸에 검은 현무암 피부·빛나는 용암 금, 숨구멍에서 연기와 불똥.
const lavaWhale = HdSpecies(_lavaWhale, extent: 1.55, ground: 1.02);

void _monsterWhale(HdKit k, Canvas c, double r, double t) => _whale(k, c, r, t, lava: false);

void _lavaWhale(HdKit k, Canvas c, double r, double t) => _whale(k, c, r, t, lava: true);

void _whale(HdKit k, Canvas c, double r, double t, {required bool lava}) {
  final grey = lava ? const Color(0xFF6A5E62) : const Color(0xFF8AA6D8);
  final greyD = lava ? const Color(0xFF221A1E) : const Color(0xFF34466E);
  final wind = k.mood == HdMood.windup;
  final down = k.mood == HdMood.down;
  final bob = k.wave(t, wind ? 2 : 1) * r * (wind ? 0.06 : 0.04);
  if (down) k.downTilt(c, r * 0.95, t);
  // 꼬리(아래 뒤로 보이는 두 갈래)
  final flick = k.wave(t, 1, 1) * r * 0.06;
  for (final s in const [-1.0, 1.0]) {
    final fluke = Path()
      ..moveTo(0, r * 0.75)
      ..quadraticBezierTo(s * r * 0.35, r * 0.85 + flick, s * r * 0.6, r * 0.78 + flick)
      ..quadraticBezierTo(s * r * 0.4, r * 1.05, 0, r * 0.95)
      ..close();
    k.blob(c, fluke, grey, greyD, gloss: false);
  }
  // 가슴지느러미(퍼덕)
  for (final s in const [-1.0, 1.0]) {
    final flap = k.wave(t, 1, s * 0.5) * 0.25;
    c
      ..save()
      ..translate(s * r * 0.72, r * 0.15 + bob)
      ..rotate(s * (0.5 + flap));
    final fin = Path()..addOval(Rect.fromCenter(center: Offset(s * r * 0.3, 0), width: r * 0.7, height: r * 0.28));
    k.blob(c, fin, grey, greyD, gloss: false);
    c.restore();
  }
  c
    ..save()
    ..translate(0, bob);
  // 몸통(큰 물방울)
  final body = Path()
    ..moveTo(0, -r * 0.95)
    ..cubicTo(r * 0.75, -r * 0.95, r * 0.95, -r * 0.2, r * 0.75, r * 0.4)
    ..quadraticBezierTo(r * 0.45, r * 0.85, 0, r * 0.85)
    ..quadraticBezierTo(-r * 0.45, r * 0.85, -r * 0.75, r * 0.4)
    ..cubicTo(-r * 0.95, -r * 0.2, -r * 0.75, -r * 0.95, 0, -r * 0.95)
    ..close();
  k
    ..blob(c, body, lava ? const Color(0xFF8A7C80) : const Color(0xFFA8C0EC), greyD)
    ..rim(c, body, lava ? const Color(0x99FFB060) : const Color(0x99E0F0FF))
    ..shine2(c, body.getBounds());
  // 흰 배(주름 줄)
  final belly = Path()
    ..moveTo(-r * 0.48, r * 0.1)
    ..quadraticBezierTo(0, -r * 0.05, r * 0.48, r * 0.1)
    ..quadraticBezierTo(r * 0.38, r * 0.8, 0, r * 0.8)
    ..quadraticBezierTo(-r * 0.38, r * 0.8, -r * 0.48, r * 0.1)
    ..close();
  k.blob(
    c,
    belly,
    lava ? const Color(0xFFFFB45A) : const Color(0xFFF4F8FF),
    lava ? const Color(0xFFD8501A) : const Color(0xFFB8C8E0),
    gloss: false,
    line: 0.6,
  );
  final w = k.ink.strokeWidth;
  k.ink.strokeWidth = w * 0.45;
  for (var i = 1; i <= 3; i++) {
    c.drawLine(Offset(-r * 0.3 + i * r * 0.15, r * 0.2), Offset(-r * 0.3 + i * r * 0.15, r * 0.7), k.ink);
  }
  k.ink.strokeWidth = w;
  if (lava) {
    // 용암 금(빛이 고리마다 일렁)
    final g = 0.7 + 0.3 * (k.wave(t, 1, 2) + 1) / 2;
    k.limb(
      c,
      Path()
        ..moveTo(-r * 0.7, -r * 0.2)
        ..lineTo(-r * 0.5, -r * 0.35)
        ..lineTo(-r * 0.55, -r * 0.6)
        ..moveTo(r * 0.72, -r * 0.05)
        ..lineTo(r * 0.5, -r * 0.2)
        ..lineTo(r * 0.58, -r * 0.5)
        ..lineTo(r * 0.4, -r * 0.72),
      Color.fromRGBO(255, (150 + 70 * g).round(), 50, 1),
      r * 0.05,
    );
  } else {
    // 따개비·흉터
    k.spots(c, r, const [(-0.55, -0.45, 0.06), (-0.62, -0.3, 0.04), (0.6, -0.1, 0.05)], const Color(0xFFDCE6F4));
    c
      ..drawLine(Offset(r * 0.3, -r * 0.7), Offset(r * 0.55, -r * 0.45), k.ink)
      ..drawLine(Offset(r * 0.36, -r * 0.5), Offset(r * 0.48, -r * 0.64), k.ink);
    // 작살 둘(나무 자루 + 쇠촉)
    for (final (x, y, a) in const [(-0.62, -0.05, -0.7), (0.55, 0.2, 0.6)]) {
      final at = Offset(x * r, y * r);
      final tip = at + Offset(a * r * 0.55, -r * 0.55);
      k
        ..limb(
          c,
          Path()
            ..moveTo(at.dx, at.dy)
            ..lineTo(tip.dx, tip.dy),
          const Color(0xFFB07A40),
          r * 0.06,
        )
        ..blob(
          c,
          Path()
            ..moveTo(tip.dx - r * 0.07, tip.dy + r * 0.02)
            ..lineTo(tip.dx + a * r * 0.12, tip.dy - r * 0.12)
            ..lineTo(tip.dx + r * 0.07, tip.dy + r * 0.04)
            ..close(),
          const Color(0xFFE0E6F0),
          const Color(0xFF8090A8),
          gloss: false,
          line: 0.6,
        );
    }
  }
  // 붉은 눈(화남) + 큰 입(이빨 몇 개)
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.42, -r * 0.42);
    if (down) {
      k.dizzyEye(c, at, r * 0.3, t * s);
      continue;
    }
    final eye = Rect.fromCenter(center: at, width: r * 0.28, height: r * 0.3);
    k.fill.color = lava ? const Color(0xFFFFB02A) : const Color(0xFFFF4A3A);
    c
      ..drawOval(eye, k.fill)
      ..drawOval(eye, k.ink);
    k.fill.color = HdKit.inkColor;
    c.drawCircle(at + Offset(-s * r * 0.02, r * 0.02), r * 0.06, k.fill);
    k.fill.color = const Color(0xFFFFFFFF);
    c
      ..drawCircle(at + Offset(-r * 0.05, -r * 0.06), r * 0.035, k.fill)
      ..drawLine(at + Offset(-s * r * 0.2, -r * 0.25), at + Offset(s * r * 0.16, -r * 0.14), k.ink);
    if (wind) k.angerEye(c, at, r * 0.3);
  }
  k.mouth(
    c,
    Path()
      ..moveTo(-r * 0.5, -r * 0.12)
      ..quadraticBezierTo(0, r * 0.02, r * 0.5, -r * 0.12)
      ..quadraticBezierTo(0, r * (wind ? 0.34 : 0.12) + (k.wave(t, 1) + 1) * r * 0.03, -r * 0.5, -r * 0.12)
      ..close(),
  );
  for (final x in const [-0.36, -0.12, 0.12]) {
    k.tooth(c, Offset(x * r, -r * 0.08), r * 0.12, r * 0.09);
  }
  // 숨구멍 물줄기(고리 앞 절반에 솟고 사라짐)
  final spout = wind ? 1.0 : (down ? 0.0 : (k.wave(t, 1, -1.2) + 1) / 2);
  if (spout > 0.25) {
    // 용암 고래는 회색 연기 + 불똥
    k.fill.color = lava ? Color.fromRGBO(90, 80, 84, 0.8 * spout) : Color.fromRGBO(220, 244, 255, 0.85 * spout);
    for (final (dx, dy, s) in const [
      (0.0, -1.2, 0.12),
      (-0.14, -1.32, 0.08),
      (0.14, -1.32, 0.08),
      (0.0, -1.42, 0.07),
    ]) {
      c.drawCircle(Offset(dx * r, (dy + 0.1 * (1 - spout)) * r), s * r * spout, k.fill);
    }
    if (lava) {
      k.fill.color = Color.fromRGBO(255, 170, 50, spout);
      c
        ..drawCircle(Offset(-r * 0.2, -r * (1.3 + spout * 0.15)), r * 0.035, k.fill)
        ..drawCircle(Offset(r * 0.22, -r * (1.25 + spout * 0.2)), r * 0.03, k.fill);
    }
  }
  c.restore();
  if (down) {
    k.dizzyStars(c, Offset(0, -r * 1.2), r, t);
    c.restore();
  }
}

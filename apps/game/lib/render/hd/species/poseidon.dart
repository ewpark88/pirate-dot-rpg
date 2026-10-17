import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 포세이돈(대보스 td_boss:poseidon): 금관·흰 수염의 바다 왕 — 삼지창을 들고 물고기 꼬리를 흔들며 떠 있다.
/// 금 어깨갑옷·허리띠, 삼지창 끝이 번쩍인다(고리마다 한 번).
const poseidon = HdSpecies(_poseidon, extent: 1.6, ground: 1.1);

void _poseidon(HdKit k, Canvas c, double r, double t) {
  const skin = Color(0xFF8CF0D8);
  const skinD = Color(0xFF2A9A8E);
  const gold = Color(0xFFFFE27A);
  const goldD = Color(0xFFD8901A);
  final bob = k.wave(t, 1) * r * 0.05;
  // 물고기 꼬리(아래로 휘어 흔들림)
  final sw = k.wave(t, 1, 1) * r * 0.12;
  final tail = Path()
    ..moveTo(-r * 0.38, r * 0.4 + bob)
    ..quadraticBezierTo(-r * 0.35, r * 0.95, sw + r * 0.1, r * 1.1)
    ..quadraticBezierTo(r * 0.32, r * 0.8, r * 0.38, r * 0.4 + bob)
    ..close();
  k
    ..blob(c, tail, const Color(0xFF6ADCC8), skinD, gloss: false)
    ..tail(c, Offset(sw + r * 0.1, r * 1.08), r * 0.32, 1.3 + sw / r, const Color(0xFF8CF0D8), skinD);
  c
    ..save()
    ..translate(0, bob);
  // 삼지창(오른손) — 몸 뒤
  final shaft = Path()
    ..moveTo(r * 0.82, r * 0.7)
    ..lineTo(r * 0.82, -r * 1.12);
  k.limb(c, shaft, gold, r * 0.07);
  final fork = Path()
    ..moveTo(r * 0.6, -r * 1.05)
    ..quadraticBezierTo(r * 0.6, -r * 0.92, r * 0.82, -r * 0.92)
    ..quadraticBezierTo(r * 1.04, -r * 0.92, r * 1.04, -r * 1.05);
  k.limb(c, fork, gold, r * 0.06);
  for (final x in const [0.6, 0.82, 1.04]) {
    k.blob(
      c,
      Path()
        ..moveTo(x * r - r * 0.06, -r * 1.05)
        ..lineTo(x * r, -r * (x == 0.82 ? 1.38 : 1.25))
        ..lineTo(x * r + r * 0.06, -r * 1.05)
        ..close(),
      gold,
      goldD,
      gloss: false,
      line: 0.6,
    );
  }
  // 몸통(근육 덩어리) + 팔
  final arm = Path()
    ..moveTo(r * 0.45, -r * 0.2)
    ..quadraticBezierTo(r * 0.8, -r * 0.1, r * 0.82, r * 0.15);
  k.limb(c, arm, skin, r * 0.24);
  final armL = Path()
    ..moveTo(-r * 0.45, -r * 0.2)
    ..quadraticBezierTo(-r * 0.8, r * 0.05 + k.wave(t, 1, 2) * r * 0.05, -r * 0.6, r * 0.35);
  k.limb(c, armL, skin, r * 0.24);
  final torso = Path()
    ..moveTo(-r * 0.5, -r * 0.3)
    ..quadraticBezierTo(0, -r * 0.42, r * 0.5, -r * 0.3)
    ..quadraticBezierTo(r * 0.5, r * 0.3, r * 0.38, r * 0.45)
    ..lineTo(-r * 0.38, r * 0.45)
    ..quadraticBezierTo(-r * 0.5, r * 0.3, -r * 0.5, -r * 0.3)
    ..close();
  k
    ..blob(c, torso, skin, skinD)
    // 손(삼지창 쥔 주먹)
    ..blob(
      c,
      Path()..addOval(Rect.fromCenter(center: Offset(r * 0.82, r * 0.18), width: r * 0.24, height: r * 0.22)),
      skin,
      skinD,
      gloss: false,
    );
  // 허리띠 + 어깨갑옷
  final belt = Path()..addRRect(RRect.fromLTRBR(-r * 0.42, r * 0.3, r * 0.42, r * 0.46, Radius.circular(r * 0.05)));
  k.blob(c, belt, gold, goldD, gloss: false, line: 0.7);
  for (final s in const [-1.0, 1.0]) {
    final pad = Path()
      ..addOval(Rect.fromCenter(center: Offset(s * r * 0.5, -r * 0.3), width: r * 0.42, height: r * 0.3));
    k.blob(c, pad, gold, goldD);
  }
  // 머리(2등신 — 몸통만큼 크게): 얼굴 → 수염 → 눈썹 짙은 눈 → 금관
  final face = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.72), width: r * 0.86, height: r * 0.8));
  k.blob(c, face, const Color(0xFFB4FFE8), skinD);
  final beard = Path()
    ..moveTo(-r * 0.42, -r * 0.66)
    ..quadraticBezierTo(-r * 0.46, -r * 0.12, 0, r * 0.02 + k.wave(t, 1) * r * 0.03)
    ..quadraticBezierTo(r * 0.46, -r * 0.12, r * 0.42, -r * 0.66)
    ..quadraticBezierTo(r * 0.2, -r * 0.5, 0, -r * 0.56)
    ..quadraticBezierTo(-r * 0.2, -r * 0.5, -r * 0.42, -r * 0.66)
    ..close();
  k.blob(c, beard, const Color(0xFFFFFFFF), const Color(0xFFC8D8E8), gloss: false);
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.18, -r * 0.8), r * 0.26, angry: true);
  }
  k.crown(c, Offset(0, -r * 1.06), r * 0.66);
  // 삼지창 번쩍(고리 끝 무렵)
  final flash = k.wave(t, 1, -2);
  if (flash > 0.6) {
    final a = (flash - 0.6) / 0.4;
    final at = Offset(r * 0.82, -r * 1.38);
    k.fill.color = Color.fromRGBO(255, 255, 255, a);
    c
      ..drawPath(
        Path()
          ..moveTo(at.dx, at.dy - r * 0.2 * a)
          ..lineTo(at.dx + r * 0.04, at.dy)
          ..lineTo(at.dx, at.dy + r * 0.2 * a)
          ..lineTo(at.dx - r * 0.04, at.dy)
          ..close(),
        k.fill,
      )
      ..drawPath(
        Path()
          ..moveTo(at.dx - r * 0.2 * a, at.dy)
          ..lineTo(at.dx, at.dy + r * 0.04)
          ..lineTo(at.dx + r * 0.2 * a, at.dy)
          ..lineTo(at.dx, at.dy - r * 0.04)
          ..close(),
        k.fill,
      );
  }
  c.restore();
}

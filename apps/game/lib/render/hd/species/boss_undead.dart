import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 해골 선장(td_boss:skeleton_captain): 해적 모자의 해골 — 칼을 휘두르고 턱이 딸깍, 빨간 줄무늬 셔츠.
const skeletonCaptain = HdSpecies(_skeletonCaptain, extent: 1.5, ground: 1.05);

/// 망령(td_boss:specter): 하늘빛 유령 — 두 팔을 들고 아래 꼬리가 흔들리며 반투명하게 둥실.
const specter = HdSpecies(_specter, extent: 1.5, ground: 1.2);

void _skeletonCaptain(HdKit k, Canvas c, double r, double t) {
  const bone = Color(0xFFF4F0E4);
  const boneD = Color(0xFFA89E88);
  final bob = k.wave(t, 1) * r * 0.04;
  final swing = k.wave(t, 1, 1) * 0.5;
  // 몸통(줄무늬 셔츠) + 팔뼈
  for (final s in const [-1.0, 1.0]) {
    k.limb(
      c,
      Path()
        ..moveTo(s * r * 0.35, -r * 0.05 + bob)
        ..lineTo(s * r * 0.55, r * 0.15 + bob),
      bone,
      r * 0.09,
    );
  }
  final shirt = Path()
    ..moveTo(-r * 0.38, -r * 0.1 + bob)
    ..lineTo(r * 0.38, -r * 0.1 + bob)
    ..lineTo(r * 0.32, r * 0.65 + bob)
    ..quadraticBezierTo(0, r * 0.75 + bob, -r * 0.32, r * 0.65 + bob)
    ..close();
  k.blob(c, shirt, const Color(0xFFFFFFFF), const Color(0xFFD0C8C0), gloss: false);
  k.fill.color = const Color(0xFFD83A3A);
  for (var i = 0; i < 3; i++) {
    c.drawRect(Rect.fromLTWH(-r * 0.36, r * (0.05 + i * 0.2) + bob, r * 0.72, r * 0.08), k.fill);
  }
  c.drawPath(shirt, k.ink);
  // 다리뼈
  for (final s in const [-1.0, 1.0]) {
    k.limb(
      c,
      Path()
        ..moveTo(s * r * 0.15, r * 0.7 + bob)
        ..lineTo(s * r * 0.18, r * 1.0),
      bone,
      r * 0.08,
    );
  }
  // 칼(오른손, 휘두름)
  c
    ..save()
    ..translate(r * 0.55, r * 0.15 + bob)
    ..rotate(-0.7 + swing);
  k
    ..blob(
      c,
      Path()
        ..moveTo(-r * 0.04, 0)
        ..quadraticBezierTo(r * 0.1, -r * 0.5, 0, -r * 0.95)
        ..quadraticBezierTo(r * 0.2, -r * 0.5, r * 0.06, 0)
        ..close(),
      const Color(0xFFF0F4FA),
      const Color(0xFF8A96A8),
      gloss: false,
      line: 0.6,
    )
    ..limb(
      c,
      Path()
        ..moveTo(-r * 0.12, 0)
        ..lineTo(r * 0.14, 0),
      const Color(0xFFFFC84A),
      r * 0.05,
    );
  c.restore();
  // 해골 + 딸깍 턱
  final jaw = (k.wave(t, 2) + 1) / 2 * r * 0.06;
  final skull = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.5 + bob), width: r * 0.82, height: r * 0.74));
  k
    ..blob(
      c,
      Path()..addRRect(
        RRect.fromLTRBR(-r * 0.22, -r * 0.22 + bob + jaw, r * 0.22, -r * 0.05 + bob + jaw, Radius.circular(r * 0.06)),
      ),
      bone,
      boneD,
      gloss: false,
      line: 0.7,
    )
    ..blob(c, skull, bone, boneD);
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.17, -r * 0.5 + bob);
    k.fill.color = HdKit.inkColor;
    c.drawOval(Rect.fromCenter(center: at, width: r * 0.22, height: r * 0.24), k.fill);
    k.fill.color = const Color(0xFFFF6A3A); // 눈구멍 속 불빛
    c.drawCircle(at + Offset(0, r * 0.02), r * 0.045, k.fill);
  }
  k.fill.color = HdKit.inkColor;
  c.drawPath(
    Path()
      ..moveTo(0, -r * 0.38 + bob)
      ..lineTo(-r * 0.04, -r * 0.3 + bob)
      ..lineTo(r * 0.04, -r * 0.3 + bob)
      ..close(),
    k.fill,
  );
  // 해적 모자(해골 무늬)
  final hat = Path()
    ..moveTo(-r * 0.62, -r * 0.72 + bob)
    ..quadraticBezierTo(-r * 0.3, -r * 1.25 + bob, 0, -r * 1.12 + bob)
    ..quadraticBezierTo(r * 0.3, -r * 1.25 + bob, r * 0.62, -r * 0.72 + bob)
    ..quadraticBezierTo(0, -r * 0.82 + bob, -r * 0.62, -r * 0.72 + bob)
    ..close();
  k
    ..blob(c, hat, const Color(0xFF4A4458), const Color(0xFF1E1A26))
    ..spots(c, r, [(0.0, -0.95 + bob / r, 0.07)], const Color(0xFFF4F0E4));
}

void _specter(HdKit k, Canvas c, double r, double t) {
  final float = k.wave(t, 1) * r * 0.08;
  final body = Path()
    ..moveTo(-r * 0.62, r * 0.35 + float)
    ..cubicTo(-r * 0.75, -r * 1.05, r * 0.75, -r * 1.05, r * 0.62, r * 0.35 + float);
  // 아래 물결 꼬리(흔들림)
  for (var i = 0; i < 4; i++) {
    final x = r * (0.62 - (i + 1) * 0.31);
    final dip = r * (0.9 + (i.isEven ? 0.12 : 0)) + k.wave(t, 1, i.toDouble()) * r * 0.08;
    body.quadraticBezierTo(x + r * 0.15, dip + float, x, r * 0.55 + float);
  }
  body.close();
  k.fill
    ..color = const Color(0xFFFFFFFF)
    ..shader = Gradient.linear(Offset(0, -r), Offset(0, r), const [Color(0xE8E8F4FF), Color(0xB08AA8E8)]);
  c.drawPath(body, k.fill);
  k.fill.shader = null;
  c.drawPath(body, k.ink);
  k.shine(c, body.getBounds());
  // 팔(위로 든)
  for (final s in const [-1.0, 1.0]) {
    final arm = Path()
      ..moveTo(s * r * 0.55, -r * 0.1 + float)
      ..quadraticBezierTo(s * r * 1.0, -r * 0.2 + float, s * r * (1.05 + k.wave(t, 2, s) * 0.05), -r * 0.65 + float);
    k.limb(c, arm, const Color(0xFFD8E4FA), r * 0.16);
  }
  // 얼굴: 검은 눈 구멍 + 벌린 입
  for (final s in const [-1.0, 1.0]) {
    k.fill.color = HdKit.inkColor;
    c.drawOval(
      Rect.fromCenter(center: Offset(s * r * 0.22, -r * 0.35 + float), width: r * 0.24, height: r * 0.34),
      k.fill,
    );
    k.fill.color = const Color(0xFFFFFFFF);
    c.drawCircle(Offset(s * r * 0.22 - r * 0.04, -r * 0.42 + float), r * 0.04, k.fill);
  }
  k.mouth(
    c,
    Path()..addOval(
      Rect.fromCenter(center: Offset(0, -r * 0.02 + float), width: r * 0.22, height: r * (0.24 + k.wave(t, 1) * 0.05)),
    ),
  );
}

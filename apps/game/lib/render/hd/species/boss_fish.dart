import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 아귀 왕(td_boss:angler_king): 금관 쓴 보라 아귀 — 머리 위 초롱이 깜빡이고 이빨 가득 입을 크게 벌린다.
const anglerKing = HdSpecies(_anglerKing, extent: 1.5, ground: 0.95);

/// 망치상어(td_boss:hammer_shark): 망치 머리 끝에 눈, 흰 배·지느러미, 이빨을 드러내고 꼬리를 흔든다(정면 3/4).
const hammerShark = HdSpecies(_hammerShark, extent: 1.5, ground: 1);

/// 회오리 돌고래(td_boss:twister_dolphin): 물줄기 고리를 두른 하늘색 돌고래 — 몸을 비틀며 물방울이 돈다.
const twisterDolphin = HdSpecies(_twisterDolphin, extent: 1.5, ground: 1.05);

/// 번개 가오리 새끼(td_boss:thunder_ray_pup): 넓은 마름모 날개를 퍼덕이는 남색 가오리 — 날개 끝에 노란 번개가 튄다.
const thunderRayPup = HdSpecies(_thunderRayPup, extent: 1.5, ground: 0.9);

void _anglerKing(HdKit k, Canvas c, double r, double t) {
  const body = Color(0xFF8A6ADC);
  const bodyD = Color(0xFF3A2470);
  final bob = k.wave(t, 1) * r * 0.04;
  k
    ..tail(c, Offset(r * 0.85, r * 0.1 + bob), r * 0.5, k.wave(t, 2) * 0.25, body, bodyD)
    // 초롱 줄기 + 초롱(깜빡)
    ..limb(
      c,
      Path()
        ..moveTo(-r * 0.1, -r * 0.7 + bob)
        ..quadraticBezierTo(-r * 0.2, -r * 1.25, -r * 0.62, -r * 1.12 + k.wave(t, 1, 1) * r * 0.05),
      bodyD,
      r * 0.06,
    );
  final glow = 0.6 + 0.4 * (k.wave(t, 2) + 1) / 2;
  final lamp = Offset(-r * 0.66, -r * 1.05 + k.wave(t, 1, 1) * r * 0.05);
  k.fill.color = Color.fromRGBO(140, 230, 255, 0.35 * glow);
  c.drawCircle(lamp, r * 0.3 * glow, k.fill);
  k.blob(
    c,
    Path()..addOval(Rect.fromCircle(center: lamp, radius: r * 0.14)),
    const Color(0xFFE8FFFF),
    const Color(0xFF5AC8F0),
    line: 0.7,
  );
  c
    ..save()
    ..translate(0, bob);
  final b = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.05), width: r * 1.85, height: r * 1.55));
  k
    ..blob(c, b, const Color(0xFFB09AF0), bodyD)
    ..spots(c, r, const [(0.45, -0.45, 0.07), (0.6, -0.2, 0.05), (0.3, -0.6, 0.04)], const Color(0x553A2470));
  // 큰 입(아래 절반) + 위아래 이빨
  final open = (k.wave(t, 1, 0.5) + 1) / 2;
  k.mouth(
    c,
    Path()
      ..moveTo(-r * 0.85, r * 0.0)
      ..quadraticBezierTo(0, -r * 0.1, r * 0.55, r * 0.05)
      ..quadraticBezierTo(r * 0.3, r * 0.55 + open * r * 0.12, -r * 0.4, r * 0.6 + open * r * 0.12)
      ..quadraticBezierTo(-r * 0.8, r * 0.4, -r * 0.85, r * 0.0)
      ..close(),
  );
  for (var i = 0; i < 6; i++) {
    k.tooth(c, Offset(-r * 0.75 + i * r * 0.21, -r * 0.03 + (i - 2.5).abs() * r * 0.012), r * 0.13, r * 0.17);
  }
  for (var i = 0; i < 4; i++) {
    k.tooth(c, Offset(-r * 0.55 + i * r * 0.2, r * 0.52 + open * r * 0.1), r * 0.12, -r * 0.14);
  }
  k
    ..eye(c, Offset(-r * 0.3, -r * 0.42), r * 0.36, angry: true, look: -0.6)
    ..eye(c, Offset(r * 0.12, -r * 0.48), r * 0.3, angry: true, look: -0.6)
    ..crown(c, Offset(r * 0.25, -r * 0.7), r * 0.5);
  c.restore();
}

void _hammerShark(HdKit k, Canvas c, double r, double t) {
  const grey = Color(0xFFA8B8D0);
  const greyD = Color(0xFF46566E);
  final bob = k.wave(t, 1) * r * 0.04;
  final sw = k.wave(t, 1, 1) * r * 0.12;
  // 꼬리(아래로 보이는 초승달)
  final tail = Path()
    ..moveTo(sw - r * 0.12, r * 0.8)
    ..quadraticBezierTo(sw - r * 0.5, r * 0.95, sw - r * 0.55, r * 1.15)
    ..quadraticBezierTo(sw, r * 0.95, sw + r * 0.5, r * 1.1)
    ..quadraticBezierTo(sw + r * 0.4, r * 0.9, sw + r * 0.12, r * 0.8)
    ..close();
  k.blob(c, tail, grey, greyD, gloss: false);
  // 가슴지느러미
  for (final s in const [-1.0, 1.0]) {
    final fin = Path()
      ..moveTo(s * r * 0.4, r * 0.15 + bob)
      ..lineTo(s * r * 1.0, r * 0.55 + bob + k.wave(t, 1, s) * r * 0.05)
      ..lineTo(s * r * 0.35, r * 0.45 + bob)
      ..close();
    k.blob(c, fin, grey, greyD, gloss: false);
  }
  c
    ..save()
    ..translate(0, bob);
  final body = Path()
    ..moveTo(-r * 0.45, -r * 0.3)
    ..quadraticBezierTo(-r * 0.6, r * 0.5, 0, r * 0.88)
    ..quadraticBezierTo(r * 0.6, r * 0.5, r * 0.45, -r * 0.3)
    ..close();
  k.blob(c, body, grey, greyD);
  final belly = Path()
    ..moveTo(-r * 0.28, r * 0.0)
    ..quadraticBezierTo(-r * 0.3, r * 0.5, 0, r * 0.75)
    ..quadraticBezierTo(r * 0.3, r * 0.5, r * 0.28, r * 0.0)
    ..close();
  k.blob(c, belly, const Color(0xFFFFFFFF), const Color(0xFFD0D8E4), gloss: false, line: 0.5);
  // 등지느러미(머리 뒤로 솟음)
  final dorsal = Path()
    ..moveTo(-r * 0.12, -r * 0.6)
    ..quadraticBezierTo(r * 0.05, -r * 1.25, r * 0.22, -r * 1.2)
    ..quadraticBezierTo(r * 0.15, -r * 0.85, r * 0.2, -r * 0.6)
    ..close();
  k.blob(c, dorsal, grey, greyD, gloss: false);
  // 망치 머리(가로로 넓게) + 끝 눈
  final head = Path()
    ..moveTo(-r * 1.15, -r * 0.62)
    ..quadraticBezierTo(-r * 1.2, -r * 0.92, -r * 0.9, -r * 0.92)
    ..lineTo(r * 0.9, -r * 0.92)
    ..quadraticBezierTo(r * 1.2, -r * 0.92, r * 1.15, -r * 0.62)
    ..quadraticBezierTo(r * 0.5, -r * 0.4, 0, -r * 0.3)
    ..quadraticBezierTo(-r * 0.5, -r * 0.4, -r * 1.15, -r * 0.62)
    ..close();
  k.blob(c, head, const Color(0xFFC8D4E8), greyD);
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.98, -r * 0.75), r * 0.28, angry: true, look: -s * 0.5);
  }
  // 입(머리 아래) + 이빨 줄
  final open = (k.wave(t, 1) + 1) / 2;
  k.mouth(
    c,
    Path()
      ..moveTo(-r * 0.35, -r * 0.35)
      ..quadraticBezierTo(0, -r * 0.42, r * 0.35, -r * 0.35)
      ..quadraticBezierTo(0, -r * 0.05 + open * r * 0.08, -r * 0.35, -r * 0.35)
      ..close(),
  );
  for (var i = 0; i < 5; i++) {
    k.tooth(c, Offset(-r * 0.3 + i * r * 0.12, -r * 0.39), r * 0.1, r * 0.1);
  }
  // 아가미 줄
  final w = k.ink.strokeWidth;
  k.ink.strokeWidth = w * 0.45;
  for (final s in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(s * r * (0.3 + i * 0.05), -r * 0.15), Offset(s * r * (0.34 + i * 0.05), r * 0.05), k.ink);
    }
  }
  k.ink.strokeWidth = w;
  c.restore();
}

void _twisterDolphin(HdKit k, Canvas c, double r, double t) {
  const blue = Color(0xFF7ACCFF);
  const blueD = Color(0xFF2A6ACC);
  final spin = 2 * math.pi * t / HdKit.loopMs;
  // 뒤쪽 물줄기 고리 + 물방울
  _swirl(k, c, r, spin, back: true);
  final twist = k.wave(t, 1) * 0.12;
  c
    ..save()
    ..rotate(twist);
  // 꼬리(아래)
  final tail = Path()
    ..moveTo(-r * 0.12, r * 0.75)
    ..quadraticBezierTo(-r * 0.5, r * 0.85, -r * 0.55, r * 1.05)
    ..quadraticBezierTo(0, r * 0.88, r * 0.55, r * 1.05)
    ..quadraticBezierTo(r * 0.5, r * 0.85, r * 0.12, r * 0.75)
    ..close();
  k.blob(c, tail, blue, blueD, gloss: false);
  for (final s in const [-1.0, 1.0]) {
    final fin = Path()
      ..moveTo(s * r * 0.4, r * 0.05)
      ..quadraticBezierTo(s * r * 0.95, r * 0.05, s * r * 0.85, r * 0.45 + k.wave(t, 2, s) * r * 0.05)
      ..quadraticBezierTo(s * r * 0.6, r * 0.35, s * r * 0.35, r * 0.35)
      ..close();
    k.blob(c, fin, blue, blueD, gloss: false);
  }
  final body = Path()
    ..moveTo(0, -r * 0.95)
    ..cubicTo(r * 0.6, -r * 0.95, r * 0.6, r * 0.4, 0, r * 0.85)
    ..cubicTo(-r * 0.6, r * 0.4, -r * 0.6, -r * 0.95, 0, -r * 0.95)
    ..close();
  k.blob(c, body, const Color(0xFFA8E0FF), blueD);
  final belly = Path()
    ..moveTo(-r * 0.25, -r * 0.2)
    ..quadraticBezierTo(0, -r * 0.3, r * 0.25, -r * 0.2)
    ..quadraticBezierTo(r * 0.22, r * 0.45, 0, r * 0.65)
    ..quadraticBezierTo(-r * 0.22, r * 0.45, -r * 0.25, -r * 0.2)
    ..close();
  k.blob(c, belly, const Color(0xFFFFFFFF), const Color(0xFFD0E8F8), gloss: false, line: 0.5);
  // 주둥이 + 웃는 입(장난꾸러기 보스)
  final beak = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.28), width: r * 0.42, height: r * 0.26));
  k.blob(c, beak, const Color(0xFFC8ECFF), blueD, gloss: false, line: 0.7);
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.22, -r * 0.6), r * 0.3, angry: true, look: s * 0.2);
  }
  k
    ..smile(c, Offset(0, -r * 0.24), r * 0.24)
    ..cheeks(c, Offset(0, -r * 0.42), r * 0.38, r * 0.16);
  c.restore();
  _swirl(k, c, r, spin, back: false);
}

/// 몸을 감는 물줄기 고리(앞·뒤 반쪽) + 고리 위를 도는 물방울 3.
void _swirl(HdKit k, Canvas c, double r, double spin, {required bool back}) {
  final rect = Rect.fromCenter(center: Offset(0, r * 0.1), width: r * 2.1, height: r * 0.7);
  k.limb(
    c,
    Path()..addArc(rect, back ? math.pi : 0, math.pi),
    const Color(0xCCDFF6FF),
    r * 0.08,
  );
  k.fill.color = const Color(0xFFFFFFFF);
  for (var i = 0; i < 3; i++) {
    final a = spin + i * 2 * math.pi / 3;
    if ((math.sin(a) < 0) != back) continue;
    c.drawCircle(Offset(math.cos(a) * r * 1.05, r * 0.1 + math.sin(a) * r * 0.35), r * 0.06, k.fill);
  }
}

void _thunderRayPup(HdKit k, Canvas c, double r, double t) {
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
    ..cheeks(c, Offset(0, -r * 0.12), r * 0.3, r * 0.14);
  // 날개 끝 번개(고리 후반에 번쩍)
  final zap = k.wave(t, 2, 1);
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

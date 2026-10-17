import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 유령 제독(유령해 해역 보스, 부하 소환): 반투명 민트 유령 몸 + 남색 제독 코트(금 견장·금단추) + 금테 이각모(해골 휘장),
/// 초록 불 눈·흰 유령 수염, 한 손엔 금 망원경을 들어 흔든다. 아래는 물결 꼬리, 주위에 초록 도깨비불 2개가 돈다.
const ghostAdmiral = HdSpecies(_ghostAdmiral, extent: 1.5, ground: 1.2);

const _coat = Color(0xFF3A4A8A);
const _coatD = Color(0xFF1E2858);
const _gold = Color(0xFFFFD45A);
const _goldD = Color(0xFFC08A20);
const _glow = Color(0xFF7CFFB0);
final _line = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

void _ghostAdmiral(HdKit k, Canvas c, double r, double t) {
  final f = k.wave(t, 1) * r * 0.07;
  // 도깨비불(뒤쪽 하나)
  _wisp(k, c, r, t, 0);
  // 유령 꼬리(코트 아래 반투명 물결)
  final tail = Path()
    ..moveTo(-r * 0.5, r * 0.2 + f)
    ..lineTo(r * 0.5, r * 0.2 + f);
  for (var i = 0; i < 4; i++) {
    final x = r * (0.5 - (i + 1) * 0.25);
    final dip = r * (0.95 + (i.isEven ? 0.1 : 0)) + k.wave(t, 1, i.toDouble()) * r * 0.08;
    tail.quadraticBezierTo(x + r * 0.12, dip + f, x, r * 0.62 + f);
  }
  tail.close();
  k.fill.shader = Gradient.linear(Offset(0, r * 0.2), Offset(0, r), const [Color(0xE0C8FFE6), Color(0x5070D8B0)]);
  c.drawPath(tail, k.fill);
  k.fill.shader = null;
  c.drawPath(tail, k.ink);
  // 팔: 왼팔은 허리, 오른팔은 망원경을 들어 흔든다
  final lift = k.wave(t, 1, 1) * 0.06;
  k.limb(
    c,
    Path()
      ..moveTo(-r * 0.42, -r * 0.05 + f)
      ..quadraticBezierTo(-r * 0.7, r * 0.15 + f, -r * 0.5, r * 0.35 + f),
    _coat,
    r * 0.17,
  );
  final hand = Offset(r * (0.82 + lift), -r * (0.45 + lift * 2) + f);
  k.limb(
    c,
    Path()
      ..moveTo(r * 0.42, -r * 0.05 + f)
      ..quadraticBezierTo(r * 0.8, -r * 0.05 + f, hand.dx, hand.dy),
    _coat,
    r * 0.17,
  );
  // 망원경(금 원통 두 마디)
  c
    ..save()
    ..translate(hand.dx, hand.dy)
    ..rotate(-0.9 + lift * 3);
  for (final (x, w, h) in const [(0.0, 0.46, 0.24), (0.4, 0.36, 0.18)]) {
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r * x, -r * h / 2, r * w, r * h), Radius.circular(r * 0.03)));
    k.blob(c, p, _gold, _goldD, gloss: false);
  }
  k.fill.color = const Color(0xFFD8FFF0); // 유령 손
  c
    ..restore()
    ..drawCircle(hand, r * 0.1, k.fill)
    ..drawCircle(hand, r * 0.1, k.ink);
  // 코트 몸통 + 금단추 + 견장
  final coat = Path()
    ..moveTo(-r * 0.46, -r * 0.2 + f)
    ..quadraticBezierTo(0, -r * 0.32 + f, r * 0.46, -r * 0.2 + f)
    ..lineTo(r * 0.52, r * 0.42 + f)
    ..quadraticBezierTo(0, r * 0.55 + f, -r * 0.52, r * 0.42 + f)
    ..close();
  k.blob(c, coat, _coat, _coatD);
  k.fill.color = const Color(0xFFD8FFF0); // 셔츠 앞섶(유령빛)
  c.drawPath(
    Path()
      ..moveTo(-r * 0.12, -r * 0.27 + f)
      ..lineTo(r * 0.12, -r * 0.27 + f)
      ..lineTo(0, r * 0.05 + f)
      ..close(),
    k.fill,
  );
  for (var i = 0; i < 3; i++) {
    for (final s in const [-1.0, 1.0]) {
      k.fill.color = _gold;
      c.drawCircle(Offset(s * r * 0.17, r * (0.08 + i * 0.12) + f), r * 0.035, k.fill);
    }
  }
  for (final s in const [-1.0, 1.0]) {
    final ep = Path()
      ..addOval(Rect.fromCenter(center: Offset(s * r * 0.44, -r * 0.2 + f), width: r * 0.3, height: r * 0.14));
    k.blob(c, ep, _gold, _goldD, gloss: false);
    _line
      ..strokeWidth = r * 0.025
      ..color = _goldD;
    for (var j = 0; j < 3; j++) {
      final x = s * r * (0.35 + j * 0.08);
      c.drawLine(Offset(x, -r * 0.14 + f), Offset(x, -r * 0.05 + f), _line);
    }
  }
  // 머리: 반투명 유령 얼굴
  final head = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.55 + f), width: r * 0.78, height: r * 0.7));
  k.fill.shader = Gradient.radial(Offset(-r * 0.1, -r * 0.65 + f), r * 0.5, const [
    Color(0xFFF0FFF8),
    Color(0xFFA8E8D0),
  ]);
  c.drawPath(head, k.fill);
  k.fill.shader = null;
  c.drawPath(head, k.ink);
  k.shine(c, head.getBounds());
  // 눈: 검은 눈구멍 속 초록 불(표정이면 커짐)
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.15, -r * 0.58 + f);
    k.fill.color = HdKit.inkColor;
    c.drawOval(Rect.fromCenter(center: at, width: r * 0.17, height: r * 0.2), k.fill);
    k.fill.color = _glow;
    c.drawCircle(at + Offset(0, r * 0.01), r * (k.mood == HdMood.windup ? 0.065 : 0.045), k.fill);
  }
  // 흰 유령 수염(물결)
  final beard = Path()
    ..moveTo(-r * 0.3, -r * 0.42 + f)
    ..quadraticBezierTo(0, -r * 0.34 + f, r * 0.3, -r * 0.42 + f)
    ..quadraticBezierTo(r * 0.2, -r * 0.18 + f, r * 0.08, -r * 0.22 + f)
    ..quadraticBezierTo(0, -r * 0.08 + f + k.wave(t, 1) * r * 0.03, -r * 0.08, -r * 0.22 + f)
    ..quadraticBezierTo(-r * 0.2, -r * 0.18 + f, -r * 0.3, -r * 0.42 + f)
    ..close();
  k.blob(c, beard, const Color(0xFFFFFFFF), const Color(0xFFC8E8DC), gloss: false);
  // 이각모: 남색 + 금테 + 해골 휘장
  final hat = Path()
    ..moveTo(-r * 0.66, -r * 0.8 + f)
    ..quadraticBezierTo(-r * 0.35, -r * 1.32 + f, 0, -r * 1.2 + f)
    ..quadraticBezierTo(r * 0.35, -r * 1.32 + f, r * 0.66, -r * 0.8 + f)
    ..quadraticBezierTo(0, -r * 0.92 + f, -r * 0.66, -r * 0.8 + f)
    ..close();
  k.blob(c, hat, _coat, _coatD);
  _line
    ..strokeWidth = r * 0.05
    ..color = _gold;
  c.drawPath(
    Path()
      ..moveTo(-r * 0.6, -r * 0.82 + f)
      ..quadraticBezierTo(0, -r * 0.93 + f, r * 0.6, -r * 0.82 + f),
    _line,
  );
  k.spots(c, r, [(0.0, -1.04 + f / r, 0.08)], const Color(0xFFF4F0E4));
  k.fill.color = HdKit.inkColor;
  for (final s in const [-1.0, 1.0]) {
    c.drawCircle(Offset(s * r * 0.028, -r * 1.05 + f), r * 0.017, k.fill);
  }
  // 도깨비불(앞쪽 하나)
  _wisp(k, c, r, t, 1);
}

/// 초록 도깨비불: 몸 둘레를 반 바퀴씩 엇갈려 돈다.
void _wisp(HdKit k, Canvas c, double r, double t, int i) {
  final a = (t + i * 0.5) * 6.2832;
  final p = Offset(r * 1.0 * (i == 0 ? -1 : 1) * (0.7 + 0.3 * (a % 1)), -r * 0.2 + r * 0.25 * k.wave(t, 1, i * 2.0));
  k.fill.color = const Color(0x557CFFB0);
  c.drawCircle(p, r * 0.16, k.fill);
  k.fill.color = _glow;
  c.drawCircle(p, r * 0.09, k.fill);
  k.fill.color = const Color(0xFFFFFFFF);
  c.drawCircle(p + Offset(-r * 0.025, -r * 0.025), r * 0.035, k.fill);
}

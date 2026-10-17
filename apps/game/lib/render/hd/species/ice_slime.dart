import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, RadialGradient;
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_v2.dart';

/// 얼음 슬라임(대보스 td_boss:ice_slime) — HD v2: 얼음 왕관을 쓴 커다란 물방울 젤리. 출렁 찌그러지고 얼음 조각이 둘레를 돌며,
/// 서리 결·림 라이트·이중 광택. 표정: 평소 / 공격 예고(붉은 눈·입 활짝·서리 입김) / 쓰러짐(소용돌이 눈·기우뚱·별).
const iceSlime = HdSpecies(_iceSlime, extent: 1.7, ground: 0.92);

void _iceSlime(HdKit k, Canvas c, double r, double t) {
  final wind = k.mood == HdMood.windup;
  final down = k.mood == HdMood.down;
  final sq = k.wave(t, wind ? 3 : 1) * (wind ? 0.07 : 0.05); // 출렁(가로↔세로), 예고 땐 빠르게 떨림
  if (down) k.downTilt(c, r * 0.8, t);
  // 둘레 얼음 조각 3개(뒤쪽 것 먼저)
  for (var i = 0; i < 3; i++) {
    final a = 2 * math.pi * (t / HdKit.loopMs + i / 3);
    final p = Offset(math.cos(a) * r * 1.15, r * 0.25 + math.sin(a) * r * 0.32);
    if (math.sin(a) < 0) _shard(k, c, p, r * 0.16, a);
  }
  c
    ..save()
    ..translate(0, r * 0.8)
    ..scale(1 + sq, 1 - sq)
    ..translate(0, -r * 0.8);
  final body = Path()
    ..moveTo(-r * 1.05, r * 0.62)
    ..cubicTo(-r * 1.25, -r * 0.2, -r * 0.7, -r * 0.95, 0, -r * 0.95)
    ..cubicTo(r * 0.7, -r * 0.95, r * 1.25, -r * 0.2, r * 1.05, r * 0.62)
    ..quadraticBezierTo(0, r * 0.95, -r * 1.05, r * 0.62)
    ..close();
  k.fill
    ..color = const Color(0xFFFFFFFF)
    ..shader = const RadialGradient(
      center: Alignment(-0.35, -0.45),
      radius: 0.9,
      colors: [Color(0xFFE6F8FF), Color(0xFF8CD2FF), Color(0xFF3A86E0)],
    ).createShader(body.getBounds());
  c.drawPath(body, k.fill);
  k.fill.shader = null;
  c.drawPath(body, k.ink);
  // 서리 결(몸 안 결정 선)
  final w0 = k.ink.strokeWidth;
  k.ink
    ..strokeWidth = w0 * 0.3
    ..color = const Color(0x66FFFFFF);
  for (final (x, y, a) in const [(-0.6, 0.1, 0.6), (0.62, 0.05, -0.5), (0.2, 0.55, 0.2)]) {
    final o = Offset(x * r, y * r);
    for (var j = 0; j < 3; j++) {
      final d = Offset(math.cos(a + j * math.pi / 3), math.sin(a + j * math.pi / 3)) * r * 0.12;
      c.drawLine(o - d, o + d, k.ink);
    }
  }
  k.ink
    ..strokeWidth = w0
    ..color = HdKit.inkColor;
  k
    ..rim(c, body, const Color(0x99E8FFFF))
    ..shine2(c, body.getBounds())
    // 속에 비치는 얼음 기포
    ..spots(c, r, const [(0.55, 0.2, 0.08), (0.7, -0.15, 0.05), (-0.65, 0.35, 0.06)], const Color(0x88FFFFFF));
  // 얼음 왕관(뾰족 5개)
  final crown = Path()..moveTo(-r * 0.55, -r * 0.82);
  for (var i = 0; i < 5; i++) {
    final x = -r * 0.55 + r * 0.22 * (i + 0.5);
    final h = (i == 2 ? 0.55 : (i.isEven ? 0.36 : 0.44)) * r;
    crown
      ..lineTo(x, -r * 0.82 - h)
      ..lineTo(x + r * 0.11, -r * 0.84);
  }
  crown.close();
  k.blob(c, crown, const Color(0xFFFFFFFF), const Color(0xFF9AD8FA), gloss: false, line: 0.55);
  // 얼굴: 화난 큰 눈 + 삐죽 입 + 볼(차가운 분홍)
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.38, -r * 0.18);
    if (down) {
      k.dizzyEye(c, at, r * 0.36, t * s);
    } else {
      k.eye(c, at, r * 0.4, angry: true, look: -0.3);
      if (wind) k.angerEye(c, at, r * 0.4);
    }
  }
  final open = wind ? r * 0.22 : (down ? r * 0.08 : k.wave(t, 1) * r * 0.04);
  k
    ..mouth(
      c,
      Path()
        ..moveTo(-r * 0.24, r * 0.2)
        ..quadraticBezierTo(0, r * 0.05, r * 0.24, r * 0.2)
        ..quadraticBezierTo(0, r * 0.42 + open, -r * 0.24, r * 0.2)
        ..close(),
    )
    ..tooth(c, Offset(-r * 0.16, r * 0.14), r * 0.12, r * 0.1)
    ..tooth(c, Offset(r * 0.04, r * 0.14), r * 0.12, r * 0.1)
    ..cheeks(c, Offset(0, r * 0.18), r * 0.62, r * 0.22);
  if (wind) {
    // 서리 입김(입에서 앞으로 퍼짐)
    final u = (t / HdKit.loopMs * 2) % 1;
    k.fill.color = Color.fromRGBO(230, 250, 255, 0.8 * (1 - u));
    for (final dx in const [-0.12, 0.0, 0.12]) {
      c.drawCircle(Offset(dx * r * (1 + u), r * (0.55 + u * 0.35)), r * (0.06 + u * 0.08), k.fill);
    }
  }
  c.restore();
  if (down) {
    k.dizzyStars(c, Offset(0, -r * 1.35), r, t);
    c.restore();
  }
  for (var i = 0; i < 3; i++) {
    final a = 2 * math.pi * (t / HdKit.loopMs + i / 3);
    final p = Offset(math.cos(a) * r * 1.15, r * 0.25 + math.sin(a) * r * 0.32);
    if (math.sin(a) >= 0) _shard(k, c, p, r * 0.16, a);
  }
}

/// 얼음 조각(마름모).
void _shard(HdKit k, Canvas c, Offset at, double s, double spin) {
  c
    ..save()
    ..translate(at.dx, at.dy)
    ..rotate(spin * 0.5);
  final p = Path()
    ..moveTo(0, -s)
    ..lineTo(s * 0.6, 0)
    ..lineTo(0, s)
    ..lineTo(-s * 0.6, 0)
    ..close();
  k.blob(c, p, const Color(0xFFFFFFFF), const Color(0xFF8CD2FF), gloss: false, line: 0.6);
  c.restore();
}

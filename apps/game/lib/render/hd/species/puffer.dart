import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_parts.dart';

/// 복어(td_enemy:puffer — 폭풍 · 단단함 · 수면 · 원거리 가시): 넓게 부푼 노란 공 + 갈색 반점 + 짧고 성긴 가시(성게와 구분),
/// 부풀었다 줄었다. 쏘는 가시 하나는 밝은 노랑. 오므린 입·성난 눈, 테 두껍게.
const puffer = HdSpecies(_puffer, extent: 1.35);

void _puffer(HdKit k, Canvas c, double r, double t) {
  final puff = 1 + k.wave(t, 1) * 0.05;
  c
    ..save()
    ..scale(puff, puff);
  k.spikes(
    c,
    r,
    10,
    0.7,
    0.98,
    0.09,
    const Color(0xFFF2E6B0),
    const Color(0xFFB8A060),
    const Color(0xFFFFF8E0),
    hot: 6,
    spin: 0.15,
  );
  // 작은 지느러미(뒤쪽).
  final fin = Path()..addOval(Rect.fromCenter(center: Offset(r * 0.75, r * 0.05), width: r * 0.32, height: r * 0.24));
  k.blob(c, fin, const Color(0xFFFFC23A), const Color(0xFFD08A10), gloss: false, line: 0.7);
  final body = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: r * 1.5, height: r * 1.3));
  final w = k.ink.strokeWidth;
  k.ink.strokeWidth = w * 1.4; // 단단함 규칙: 테 두껍게
  k.blob(c, body, const Color(0xFFFFE27A), const Color(0xFFE0A020));
  k.ink.strokeWidth = w;
  // 흰 배 + 갈색 반점.
  k.fill.color = const Color(0xFFFFF8E0);
  c.drawOval(Rect.fromCenter(center: Offset(-r * 0.05, r * 0.35), width: r * 1.0, height: r * 0.42), k.fill);
  k
    ..spots(c, r, const [
      (0.15, -0.42, 0.07),
      (0.42, -0.2, 0.08),
      (0.5, 0.1, 0.06),
      (-0.05, -0.5, 0.05),
    ], const Color(0xFFA0642A))
    ..eye(c, Offset(-r * 0.35, -r * 0.15), r * 0.32, angry: true, look: -1);
  // 오므린 입(앞).
  k.fill.color = const Color(0xFFE5506A);
  c
    ..drawCircle(Offset(-r * 0.7, r * 0.12), r * 0.08, k.fill)
    ..drawCircle(Offset(-r * 0.7, r * 0.12), r * 0.08, k.ink)
    ..restore();
}

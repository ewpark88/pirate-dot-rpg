import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_parts.dart';

/// 성게(td_enemy:urchin — 폭풍 · 단단함 · 수중 · 원거리 가시): 넓고 낮은 보라 몸 + 굵은 가시 고리(끝 노랑),
/// 쏘는 가시 하나는 밝은 노랑으로 크게(왼쪽 위 — 보는 쪽). 테 두껍게, 거품.
const urchin = HdSpecies(_urchin);

void _urchin(HdKit k, Canvas c, double r, double t) {
  final sway = k.wave(t, 1) * 0.06;
  // 쏘는 가시는 왼쪽 위(보는 쪽) — 14개 중 9번째가 약 −130°.
  k.spikes(
    c,
    r,
    14,
    0.55,
    1.2,
    0.13,
    const Color(0xFF8A4FC8),
    const Color(0xFF4A2380),
    const Color(0xFFFFD34A),
    hot: 9,
    spin: sway,
  );
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.05), width: r * 1.5, height: r * 1.15));
  final w = k.ink.strokeWidth;
  k.ink.strokeWidth = w * 1.4; // 단단함 규칙: 테 두껍게
  k.blob(c, body, const Color(0xFFB07AE8), const Color(0xFF5A2A96));
  k.ink.strokeWidth = w;
  k
    ..eye(c, Offset(-r * 0.38, -r * 0.05), r * 0.3, angry: true, look: -1)
    ..eye(c, Offset(r * 0.05, -r * 0.02), r * 0.26, angry: true, look: -1)
    ..underwater(c, body)
    ..bubbles(c, r, t, at: Offset(-r * 0.9, -r * 0.3));
}

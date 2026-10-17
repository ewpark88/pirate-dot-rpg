import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 심해 장어(td_enemy:eel — 빠름·수중·가장 빠름, docs/specs/economy-hd-monsters-b.md): 길고 가는 S자 청록 몸, 등 지느러미 한 줄,
/// 옆구리 노란 발광 점선, 가늘게 뜨고 앞을 노려보는 눈. S자로 꿈틀 + 꼬리 잔상.
const eel = HdSpecies(_eel, extent: 1.5, ground: 0.6);

const _teal = Color(0xFF3AC8A0);
const _tealD = Color(0xFF14604E);
const _glow = Color(0xFFFFE070);

/// 몸 중심선 위 점(u 0 = 머리 ~ 1 = 꼬리 끝).
Offset _spine(double r, double t, double u) {
  final x = -r * 0.9 + u * r * 2.0;
  final y = math.sin(u * math.pi * 1.6 - 2 * math.pi * 2 * t / HdKit.loopMs) * r * 0.28 * u;
  return Offset(x, y);
}

void _eel(HdKit k, Canvas c, double r, double t) {
  // 1) 꼬리 잔상(뒤로 옅게 두 겹 — 붓 재사용, 점으로)
  for (var g = 2; g >= 1; g--) {
    k.fill.color = _teal.withValues(alpha: 0.2 / g);
    for (var i = 4; i <= 10; i++) {
      final q = _spine(r, t - g * 60, i / 10) + Offset(g * r * 0.12, 0);
      c.drawCircle(q, r * (0.13 - 0.008 * i), k.fill);
    }
  }
  // 2) 몸(두께가 머리 → 꼬리로 가늘어지는 S자 띠)
  final top = <Offset>[];
  final bottom = <Offset>[];
  for (var i = 0; i <= 12; i++) {
    final u = i / 12;
    final a = _spine(r, t, u);
    final b = _spine(r, t, math.min(1, u + 0.02));
    final d = b - a;
    final n = Offset(-d.dy, d.dx) / math.max(0.001, d.distance);
    final w = r * (0.44 - 0.34 * u);
    top.add(a + n * w);
    bottom.add(a - n * w);
  }
  final body = Path()..moveTo(top.first.dx, top.first.dy);
  for (final p in top.skip(1)) {
    body.lineTo(p.dx, p.dy);
  }
  for (final p in bottom.reversed) {
    body.lineTo(p.dx, p.dy);
  }
  body.close();
  // 등 지느러미(몸 위 얇은 띠)
  final fin = Path()..moveTo(top[2].dx, top[2].dy);
  for (var i = 2; i <= 10; i++) {
    final q = top[i] + Offset(0, -r * 0.12);
    fin.lineTo(q.dx, q.dy);
  }
  for (var i = 10; i >= 2; i--) {
    fin.lineTo(top[i].dx, top[i].dy);
  }
  fin.close();
  k
    ..blob(c, fin, const Color(0xFF8AF0C8), _tealD, gloss: false, line: 0.6)
    ..blob(c, body, const Color(0xFF6AE8C0), _tealD);
  // 3) 옆구리 발광 점선(꿈틀 따라 깜빡)
  for (var i = 3; i <= 10; i += 2) {
    final at = _spine(r, t, i / 12);
    k.fill.color = _glow.withValues(alpha: 0.6 + 0.4 * k.wave(t, 2, i.toDouble()));
    c.drawCircle(at, r * 0.05, k.fill);
  }
  k.underwater(c, body); // 얼굴보다 먼저
  // 4) 머리(왼쪽): 가늘게 뜬 노려보는 눈 + 입선
  final head = _spine(r, t, 0.04);
  k.eye(c, head + Offset(r * 0.05, -r * 0.14), r * 0.32, angry: true, look: -1);
  c.drawLine(head + Offset(-r * 0.3, r * 0.1), head + Offset(-r * 0.05, r * 0.14), k.ink);
  k.bubbles(c, r, t, at: Offset(-r * 0.6, 0));
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_v2.dart';

/// 저주 갈매기(td_enemy:cursegull — 공중·빠름·약함, docs/specs/economy-hd-monsters-b.md): 썩은 녹색 몸, 찢어진 날개깃(보라 테),
/// 목에 저주 사슬 한 줄, 빨간 점 눈(사나움). 날갯짓 + 깃털 하나가 떨어진다.
const cursegull = HdSpecies(_cursegull, extent: 1.5, ground: 1.25);

const _rot = Color(0xFFA8C870);
const _rotD = Color(0xFF4A5A2A);

void _cursegull(HdKit k, Canvas c, double r, double t) {
  final flap = (k.wave(t, 2) + 1) / 2;
  final bob = -k.wave(t, 2) * r * 0.08;
  // 1) 떨어지는 깃털(한 고리에 한 번)
  final u = (t / HdKit.loopMs) % 1;
  c
    ..save()
    ..translate(r * (0.5 + 0.2 * math.sin(u * 2 * math.pi)), r * (0.6 + u * 0.7))
    ..rotate(u * 3);
  k.fill.color = const Color(0xFF8AA858).withValues(alpha: 1 - u);
  c
    ..drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.12, height: r * 0.32), k.fill)
    ..restore();
  // 2) 날개 둘(찢어진 깃 — 보라 테 날개)
  k
    ..wing(
      c,
      Offset(r * 0.1, -r * 0.05 + bob),
      r * 1.15,
      -math.pi * 0.15,
      flap,
      const Color(0xFF8AA858),
      const Color(0xFF5A3A7A),
    )
    ..wing(c, Offset(-r * 0.1, -r * 0.05 + bob), r * 1.2, -math.pi * 0.85, flap, _rot, const Color(0xFF5A3A7A))
    // 3) 몸 + 꼬리깃
    ..tail(c, Offset(r * 0.45, r * 0.2 + bob), r * 0.45, 0.3, _rot, _rotD);
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.12 + bob), width: r * 1.1, height: r * 0.85));
  k.blob(c, body, const Color(0xFFD0E0A0), _rotD);
  // 4) 저주 사슬(목 둘레 고리 4)
  for (var i = 0; i < 4; i++) {
    final at = Offset(-r * 0.3 + i * r * 0.17, r * 0.0 + bob + (i.isEven ? 0 : r * 0.04));
    final ring = Rect.fromCenter(center: at, width: r * 0.16, height: r * 0.11);
    k.fill.color = const Color(0xFF7A5AA8);
    c
      ..drawOval(ring, k.fill)
      ..drawOval(ring, k.ink);
  }
  // 5) 부리 + 빨간 점 눈(사나운 눈썹)
  k.blob(
    c,
    Path()
      ..moveTo(-r * 0.5, -r * 0.12 + bob)
      ..lineTo(-r * 0.9, -r * 0.02 + bob)
      ..lineTo(-r * 0.5, r * 0.08 + bob)
      ..close(),
    const Color(0xFFE0C060),
    const Color(0xFF8A6A2A),
    gloss: false,
    line: 0.6,
  );
  final eye = Offset(-r * 0.22, -r * 0.2 + bob);
  if (k.mood == HdMood.hit) return k.squintEye(c, eye, r * 0.3); // 맞음: 찡긋(잡몹 v2)
  k.fill.color = const Color(0xFFFFFFFF);
  c
    ..drawOval(Rect.fromCenter(center: eye, width: r * 0.28, height: r * 0.3), k.fill)
    ..drawOval(Rect.fromCenter(center: eye, width: r * 0.28, height: r * 0.3), k.ink);
  k.fill.color = const Color(0xFFFF2A2A);
  c
    ..drawCircle(eye + Offset(-r * 0.03, r * 0.02), r * 0.07, k.fill)
    ..drawLine(eye + Offset(-r * 0.2, -r * 0.2), eye + Offset(r * 0.14, -r * 0.1), k.ink);
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 아귀(td_enemy:angler — 부활·수중, docs/specs/economy-hd-monsters-b.md): 둥근 남보라 몸, 이마 낚싯대 끝 노란 등불(= 부활 심지),
/// 뾰족한 이빨 큰 입, 작은 째진 눈. 등불이 흔들리고 지느러미가 꿈틀.
const angler = HdSpecies(_angler, extent: 1.45, ground: 0.8);

const _body = Color(0xFF6A5AC8);
const _bodyD = Color(0xFF2A1E5A);
const _lure = Color(0xFFFFE070);

void _angler(HdKit k, Canvas c, double r, double t) {
  final bob = k.wave(t, 1) * r * 0.06;
  final sway = k.wave(t, 1, 0.8);
  // 1) 꼬리(오른쪽)·지느러미
  k
    ..tail(c, Offset(r * 0.8, r * 0.05 + bob), r * 0.55, k.wave(t, 2) * 0.3, const Color(0xFF8A7AE0), _bodyD)
    ..tail(
      c,
      Offset(-r * 0.05, r * 0.65 + bob),
      r * 0.35,
      math.pi / 2 + k.wave(t, 2, 1) * 0.25,
      const Color(0xFF8A7AE0),
      _bodyD,
    );
  // 2) 몸
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, bob), width: r * 1.75, height: r * 1.5));
  k.blob(c, body, _body, _bodyD);
  // 3) 큰 입 + 이빨(왼쪽 아래)
  final mouth = Path()
    ..moveTo(-r * 0.88, -r * 0.05 + bob)
    ..quadraticBezierTo(-r * 0.4, r * 0.75 + bob, r * 0.2, r * 0.2 + bob)
    ..quadraticBezierTo(-r * 0.3, r * 0.3 + bob, -r * 0.88, -r * 0.05 + bob)
    ..close();
  k.mouth(c, mouth);
  for (var i = 0; i < 4; i++) {
    final x = -r * (0.72 - i * 0.22);
    k.tooth(c, Offset(x, r * (0.1 + i * 0.05) + bob), r * 0.13, r * 0.16);
  }
  // 4) 낚싯대 + 등불(부활 심지 — 흔들림, 빛 무리)
  final tip = Offset(-r * 0.75 + sway * r * 0.18, -r * 1.15 + bob);
  k.limb(
    c,
    Path()
      ..moveTo(-r * 0.05, -r * 0.7 + bob)
      ..quadraticBezierTo(-r * 0.2, -r * 1.35 + bob, tip.dx, tip.dy),
    _bodyD,
    k.ink.strokeWidth * 0.6,
  );
  k.fill.color = _lure.withValues(alpha: 0.28 + 0.12 * k.wave(t, 2));
  c.drawCircle(tip, r * 0.34, k.fill);
  // 5) 등불 알 + 작은 째진 눈 + 수중 물빛·거품
  k
    ..blob(
      c,
      Path()..addOval(Rect.fromCircle(center: tip, radius: r * 0.16)),
      const Color(0xFFFFFFE0),
      _lure,
      line: 0.6,
    )
    ..eye(c, Offset(-r * 0.2, -r * 0.3 + bob), r * 0.28, angry: true, look: -0.7)
    ..underwater(c, body)
    ..bubbles(c, r, t, at: Offset(0, bob));
}

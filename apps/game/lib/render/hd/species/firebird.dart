import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 불새(td_enemy:firebird — 공중·원거리 불씨·빠름·약함, docs/specs/economy-hd-monsters-b.md): 끝이 흩날리는 불꽃 날개, 불씨 꼬리,
/// 날카로운 눈. 날갯짓 + 불씨가 떨어지고, 쏘기 전 부리가 달아오른다. 떠 있어 그림자는 멀리 아래.
const firebird = HdSpecies(_firebird, extent: 1.5, ground: 1.25);

const _fire = Color(0xFFFFC040);
const _fireD = Color(0xFFE0401E);

void _firebird(HdKit k, Canvas c, double r, double t) {
  final flap = (k.wave(t, 2) + 1) / 2; // 0 접힘 ~ 1 펼침
  final bob = -k.wave(t, 2) * r * 0.08; // 날개를 내리칠 때 몸이 오른다
  final beak = math.pow((k.wave(t, 1, -math.pi / 2) + 1) / 2, 3).toDouble();
  // 1) 불씨 꼬리(3갈래, 뒤 = 오른쪽 아래)
  for (var i = 0; i < 3; i++) {
    final a = math.pi * (0.2 + i * 0.13);
    k.tentacle(
      c,
      Offset(r * 0.3, r * 0.35 + bob),
      a,
      r * (0.8 - i * 0.12),
      2 * math.pi * t / HdKit.loopMs + i,
      i == 1 ? _fire : _fireD,
      r * 0.14,
    );
  }
  // 떨어지는 불씨
  for (var i = 0; i < 3; i++) {
    final u = (t / HdKit.loopMs + i / 3) % 1;
    k.fill.color = Color.lerp(const Color(0xFFFFE070), const Color(0x00E0401E), u)!;
    c.drawCircle(Offset(r * (0.55 + i * 0.15), r * (0.7 + u * 0.6) + bob), r * 0.06 * (1 - u * 0.5), k.fill);
  }
  // 2) 날개 둘(뒤 날개는 조금 어둡게)
  k
    ..wing(c, Offset(r * 0.1, -r * 0.1 + bob), r * 1.2, -math.pi * 0.2, flap, const Color(0xFFFF9A3A), _fireD)
    ..wing(c, Offset(-r * 0.1, -r * 0.05 + bob), r * 1.25, -math.pi * 0.8, flap, _fire, _fireD);
  // 3) 몸(물방울꼴) + 볏 불꽃
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.1 + bob), width: r * 1.05, height: r * 0.95));
  k.blob(c, body, const Color(0xFFFFE070), _fireD);
  for (var i = 0; i < 3; i++) {
    final x = -r * (0.25 - i * 0.18);
    final h = r * (0.35 + 0.08 * k.wave(t, 4, i.toDouble()));
    k.blob(
      c,
      Path()
        ..moveTo(x - r * 0.1, -r * 0.3 + bob)
        ..quadraticBezierTo(x - r * 0.05, -r * 0.3 - h + bob, x + r * 0.08, -r * 0.32 - h + bob)
        ..quadraticBezierTo(x + r * 0.02, -r * 0.35 + bob, x + r * 0.12, -r * 0.3 + bob)
        ..close(),
      _fire,
      _fireD,
      gloss: false,
      line: 0.6,
    );
  }
  // 4) 부리(왼쪽, 쏘기 전 달아오름) + 날카로운 눈
  k
    ..blob(
      c,
      Path()
        ..moveTo(-r * 0.45, r * 0.0 + bob)
        ..lineTo(-r * 0.85, r * 0.12 + bob)
        ..lineTo(-r * 0.45, r * 0.24 + bob)
        ..close(),
      Color.lerp(const Color(0xFFFFE9B0), const Color(0xFFFFFFFF), beak)!,
      Color.lerp(const Color(0xFFE8862E), const Color(0xFFFF2A1A), beak)!,
      gloss: false,
      line: 0.6,
    )
    ..eye(c, Offset(-r * 0.18, -r * 0.08 + bob), r * 0.3, angry: true, look: -0.8);
}

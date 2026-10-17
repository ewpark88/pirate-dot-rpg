import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 관해파리(td_enemy:siphon — 부활·수중·약함, docs/specs/economy-hd-monsters-b.md): 하늘빛 화살 모양 투명한 몸 + 길게 늘어진
/// 촉수 줄, 몸속 빛 알갱이 3(= 부활 심지, 눈 대신). 촉수 줄이 물결치고 알갱이가 차례로 깜빡인다.
const siphon = HdSpecies(_siphon, extent: 1.5, ground: 0.95);

const _sky = Color(0xFF8AE8FF);
const _skyD = Color(0xFF2A8AC8);

void _siphon(HdKit k, Canvas c, double r, double t) {
  final bob = k.wave(t, 1) * r * 0.07;
  // 1) 촉수 줄 3(아래로 길게, 물결)
  for (var i = 0; i < 3; i++) {
    k.tentacle(
      c,
      Offset((i - 1) * r * 0.22, r * 0.25 + bob),
      math.pi / 2 + (i - 1) * 0.18,
      r * 1.0,
      2 * math.pi * t / HdKit.loopMs + i * 1.3,
      const Color(0xCCB0F0FF),
      r * 0.08,
      n: 6,
    );
  }
  // 2) 날개 지느러미(양옆 반투명)
  for (final s in const [-1.0, 1.0]) {
    k.blob(
      c,
      Path()
        ..moveTo(s * r * 0.15, -r * 0.2 + bob)
        ..quadraticBezierTo(s * r * (0.85 + 0.08 * k.wave(t, 2)), r * 0.0 + bob, s * r * 0.3, r * 0.3 + bob)
        ..close(),
      const Color(0xCCD0F8FF),
      const Color(0xCC5AB8E0),
      gloss: false,
      line: 0.6,
    );
  }
  // 3) 화살 몸(위 뾰족)
  final body = Path()
    ..moveTo(0, -r * 1.0 + bob)
    ..quadraticBezierTo(r * 0.45, -r * 0.2 + bob, r * 0.3, r * 0.35 + bob)
    ..quadraticBezierTo(0, r * 0.5 + bob, -r * 0.3, r * 0.35 + bob)
    ..quadraticBezierTo(-r * 0.45, -r * 0.2 + bob, 0, -r * 1.0 + bob)
    ..close();
  k.blob(c, body, const Color(0xEEE0FAFF), _skyD);
  // 4) 빛 알갱이 3(차례로 깜빡 — 눈처럼, 부활 심지)
  for (var i = 0; i < 3; i++) {
    final on = (k.wave(t, 1, -i * 2 * math.pi / 3) + 1) / 2;
    final at = Offset(0, -r * (0.5 - i * 0.28) + bob);
    k.fill.color = _sky.withValues(alpha: 0.3 + 0.3 * on);
    c.drawCircle(at, r * 0.2, k.fill);
    k.fill.color = Color.lerp(_sky, const Color(0xFFFFFFFF), on)!;
    c.drawCircle(at, r * 0.09, k.fill);
  }
  k
    ..underwater(c, body)
    ..bubbles(c, r, t, at: Offset(0, bob));
}

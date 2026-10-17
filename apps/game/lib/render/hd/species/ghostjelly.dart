import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 유령 해파리(td_enemy:ghostjelly — 부활·공중·약함, docs/specs/economy-hd-monsters-b.md): 옥빛 반투명 갓 + 끊어진 촉수, 갓 안 혼불
/// (= 부활 심지), 처진 슬픈 눈. 둥실둥실 위아래 + 촉수가 흩날린다. 떠 있어 그림자는 멀리.
const ghostjelly = HdSpecies(_ghostjelly, extent: 1.45, ground: 1.3);

const _jade = Color(0xF4D0FFF4);
const _jadeD = Color(0xF05ACCB0); // 어두운 유령 바다에서도 튀게 밝고 거의 불투명(S1)

void _ghostjelly(HdKit k, Canvas c, double r, double t) {
  final bob = k.wave(t, 1) * r * 0.1;
  final pulse = 1 + k.wave(t, 2) * 0.05;
  final soul = (k.wave(t, 1, 1) + 1) / 2;
  // 1) 끊어진 촉수 4(짧고 끝이 흩어짐)
  for (var i = 0; i < 4; i++) {
    final x = (i - 1.5) * r * 0.32;
    k.tentacle(
      c,
      Offset(x, r * 0.25 + bob),
      math.pi / 2,
      r * (0.55 + (i.isEven ? 0.15 : 0)),
      2 * math.pi * t / HdKit.loopMs + i,
      const Color(0xEEA8FFE8),
      r * 0.1,
    );
  }
  // 2) 반투명 갓
  final dome = Path()
    ..moveTo(-r * 0.9 * pulse, r * 0.3 + bob)
    ..cubicTo(-r * 0.95 * pulse, -r * 1.05 + bob, r * 0.95 * pulse, -r * 1.05 + bob, r * 0.9 * pulse, r * 0.3 + bob)
    ..quadraticBezierTo(r * 0.45, r * 0.15 + bob, 0, r * 0.32 + bob)
    ..quadraticBezierTo(-r * 0.45, r * 0.15 + bob, -r * 0.9 * pulse, r * 0.3 + bob)
    ..close();
  k.blob(c, dome, _jade, _jadeD);
  // 3) 갓 안 혼불(부활 심지)
  k.fill.color = const Color(0xFFFFFFFF).withValues(alpha: 0.35 + 0.35 * soul);
  c.drawCircle(Offset(r * 0.35, -r * 0.45 + bob), r * (0.13 + 0.04 * soul), k.fill);
  // 4) 처진 슬픈 눈 + 작은 입(아래로)
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.3, -r * 0.18 + bob);
    k.eye(c, at, r * 0.3, look: s * -0.2);
    c.drawLine(at + Offset(-s * r * 0.2, -r * 0.3), at + Offset(s * r * 0.15, -r * 0.38), k.ink);
  }
  c.drawPath(
    Path()
      ..moveTo(-r * 0.1, r * 0.12 + bob)
      ..quadraticBezierTo(0, r * 0.04 + bob, r * 0.1, r * 0.12 + bob),
    k.ink,
  );
}

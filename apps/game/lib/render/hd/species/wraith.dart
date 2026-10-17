import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 망령(td_enemy:wraith — 부활·수면, docs/specs/economy-hd-monsters-b.md): 두건 쓴 듯한 둥근 머리, 아래로 흩어지는 꼬리(다리 없음),
/// 가슴 혼불(= 부활 심지), 검은 빈 눈(무표정). 좌우로 흔들리며 미끄러지고 꼬리가 일렁인다.
const wraith = HdSpecies(_wraith, extent: 1.45, ground: 1.05);

const _mist = Color(0xEEC8FFF4);
const _mistD = Color(0xEE4AA8A0);

void _wraith(HdKit k, Canvas c, double r, double t) {
  final sway = k.wave(t, 1) * r * 0.1;
  final lean = k.wave(t, 1) * 0.08;
  final soul = (k.wave(t, 2) + 1) / 2;
  c
    ..save()
    ..translate(sway, 0)
    ..rotate(lean);
  // 1) 몸 + 흩어지는 꼬리(물결 끝 3갈래)
  final body = Path()
    ..moveTo(-r * 0.62, -r * 0.35)
    ..cubicTo(-r * 0.7, -r * 1.25, r * 0.7, -r * 1.25, r * 0.62, -r * 0.35);
  for (var i = 0; i < 3; i++) {
    final x0 = r * (0.62 - i * 0.41);
    final x1 = x0 - r * 0.41;
    final dip = r * (0.95 + 0.12 * k.wave(t, 2, i * 1.7));
    body
      ..quadraticBezierTo(x0 - r * 0.05, r * 0.5, (x0 + x1) / 2 + r * 0.05 * math.sin(i + 1.0), dip)
      ..quadraticBezierTo(x1 + r * 0.05, r * 0.5, x1, r * 0.35);
  }
  body
    ..lineTo(-r * 0.62, -r * 0.35)
    ..close();
  // 2) 두건 테(머리 둘레 진한 띠)
  k
    ..blob(c, body, _mist, _mistD)
    ..limb(
      c,
      Path()
        ..moveTo(-r * 0.6, -r * 0.3)
        ..cubicTo(-r * 0.62, -r * 1.05, r * 0.62, -r * 1.05, r * 0.6, -r * 0.3),
      const Color(0xAA3A8A84),
      r * 0.1,
    );
  // 3) 가슴 혼불(부활 심지)
  k.fill.color = const Color(0xFFFFFFFF).withValues(alpha: 0.4 + 0.4 * soul);
  c.drawCircle(Offset(0, r * 0.15), r * (0.14 + 0.05 * soul), k.fill);
  k.fill.color = const Color(0xFF8AF0E0).withValues(alpha: 0.5);
  c.drawCircle(Offset(0, r * 0.15), r * (0.26 + 0.05 * soul), k.fill);
  // 4) 검은 빈 눈 둘(무표정, 세로 타원) + 작은 'o' 입
  k.fill.color = HdKit.inkColor;
  for (final s in const [-1.0, 1.0]) {
    c.drawOval(Rect.fromCenter(center: Offset(s * r * 0.22, -r * 0.45), width: r * 0.24, height: r * 0.34), k.fill);
  }
  c
    ..drawOval(Rect.fromCenter(center: Offset(0, -r * 0.2), width: r * 0.1, height: r * 0.12), k.fill)
    ..restore();
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 용암거북(td_enemy:lavaturtle — 단단함·수면·HP 2배·느림, docs/specs/economy-hd-monsters-b.md): 넓고 낮은 화산암 등딱지(육각 판,
/// 판 사이 용암 빛), 짧은 다리 4, 반쯤 감은 졸린 눈. 느린 헤엄 + 등 용암 빛 맥박.
const lavaturtle = HdSpecies(_lavaturtle, ground: 0.6);

const _rock = Color(0xFF7E6E66);
const _rockD = Color(0xFF34282A);
const _skin = Color(0xFFE0B070);
const _skinD = Color(0xFF9A6234);

void _lavaturtle(HdKit k, Canvas c, double r, double t) {
  final bob = k.wave(t, 1) * r * 0.05;
  final paddle = k.wave(t, 1);
  final glow = Color.lerp(const Color(0xFFE0501E), const Color(0xFFFFC040), (k.wave(t, 1, 1) + 1) / 2)!;
  // 1) 다리 4(앞뒤로 젓기) + 꼬리
  for (final (x, y, ph) in const [
    (-0.85, -0.05, 0.0),
    (0.85, -0.05, math.pi),
    (-0.7, 0.45, math.pi),
    (0.7, 0.45, 0.0),
  ]) {
    final leg = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(r * x, r * (y + 0.08 * math.sin(ph) * paddle) + bob),
          width: r * 0.42,
          height: r * 0.3,
        ),
      );
    k.blob(c, leg, _skin, _skinD, gloss: false, line: 0.8);
  }
  // 3) 등딱지: 넓고 낮은 돔 + 아래 테
  final rim = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.18 + bob), width: r * 1.85, height: r * 0.7));
  k.blob(c, rim, _rock, _rockD, gloss: false);
  final dome = Path()
    ..moveTo(-r * 0.88, r * 0.15 + bob)
    ..cubicTo(-r * 0.8, -r * 0.75 + bob, r * 0.8, -r * 0.75 + bob, r * 0.88, r * 0.15 + bob)
    ..close();
  k.blob(c, dome, const Color(0xFF9E8C82), _rockD);
  // 4) 육각 판 사이 용암 빛(판 경계 선)
  final seams = Path()
    ..moveTo(-r * 0.25, -r * 0.42 + bob)
    ..lineTo(r * 0.25, -r * 0.42 + bob)
    ..moveTo(-r * 0.25, -r * 0.42 + bob)
    ..lineTo(-r * 0.45, -r * 0.08 + bob)
    ..lineTo(-r * 0.25, r * 0.14 + bob)
    ..moveTo(r * 0.25, -r * 0.42 + bob)
    ..lineTo(r * 0.45, -r * 0.08 + bob)
    ..lineTo(r * 0.25, r * 0.14 + bob)
    ..moveTo(-r * 0.25, r * 0.14 + bob)
    ..lineTo(r * 0.25, r * 0.14 + bob)
    ..moveTo(-r * 0.45, -r * 0.08 + bob)
    ..lineTo(-r * 0.82, -r * 0.02 + bob)
    ..moveTo(r * 0.45, -r * 0.08 + bob)
    ..lineTo(r * 0.82, -r * 0.02 + bob);
  k
    ..limb(c, seams, glow, k.ink.strokeWidth * 0.55)
    ..shine(c, dome.getBounds());
  // 5) 머리(왼쪽 앞으로 크게 내밂 — 등딱지 위에 그려 다 보이게) + 졸린 눈(위 35%만 눈꺼풀)
  final head = Path()
    ..addOval(Rect.fromCenter(center: Offset(-r * 1.0, -r * 0.32 + bob), width: r * 1.2, height: r * 1.05));
  k.blob(c, head, _skin, _skinD);
  final eyeAt = Offset(-r * 1.05, -r * 0.45 + bob);
  final s = r * 0.55;
  k.eye(c, eyeAt, s, look: -0.6);
  final white = Rect.fromCenter(center: eyeAt, width: s, height: s * 1.15);
  c
    ..save()
    ..clipPath(Path()..addOval(white));
  k.fill.color = _skin;
  c
    ..drawRect(Rect.fromLTWH(white.left, white.top, white.width, white.height * 0.35), k.fill)
    ..restore()
    ..drawLine(
      Offset(white.left + s * 0.05, white.top + white.height * 0.35),
      Offset(white.right - s * 0.05, white.top + white.height * 0.35),
      k.ink,
    )
    ..drawOval(white, k.ink);
  k.smile(c, Offset(-r * 1.05, -r * 0.08 + bob), r * 0.24);
}

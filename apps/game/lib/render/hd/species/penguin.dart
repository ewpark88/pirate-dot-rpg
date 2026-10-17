import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 펭귄(td_enemy:penguin — 빙하 · 빠름 · 수면 · 원거리 눈덩이): 배로 미끄러지는 길쭉한 몸(앞으로 기움) + 뒤로 잔상,
/// 짧은 날개 끝에 눈덩이(쏘는 부위 — 흰 공 강조), 주황 부리·발, 볼 홍조의 신난 표정.
const penguin = HdSpecies(_penguin, extent: 1.25, muzzle: Offset(-0.38, -0.26));

void _penguin(HdKit k, Canvas c, double r, double t) {
  final slide = k.wave(t, 2) * r * 0.03;
  // 빠름 규칙: 뒤로 미끄럼 잔상 줄.
  for (final dy in const [0.15, 0.4]) {
    k.limb(
      c,
      Path()
        ..moveTo(r * 0.95, r * dy)
        ..lineTo(r * 1.4, r * dy),
      const Color(0xCCE8F8FF),
      r * 0.06,
    );
  }
  c
    ..save()
    ..translate(slide, 0)
    ..rotate(-0.12); // 앞(왼쪽)으로 살짝 기움 — 배 미끄럼
  // 발(뒤로 뻗음).
  final foot = Path()..addOval(Rect.fromCenter(center: Offset(r * 0.8, r * 0.35), width: r * 0.36, height: r * 0.18));
  k.blob(c, foot, const Color(0xFFFFA24A), const Color(0xFFD86A10), gloss: false, line: 0.6);
  // 몸(옆으로 누운 길쭉한 검남 몸) + 흰 배.
  final body = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: r * 1.75, height: r * 1.05));
  k.blob(c, body, const Color(0xFF3A4670), const Color(0xFF161C34));
  // 흰 배: 아래쪽 반만(검은 등이 위로 보이게).
  k.fill.color = const Color(0xFFF8FBFF);
  c.drawOval(Rect.fromCenter(center: Offset(-r * 0.1, r * 0.25), width: r * 1.3, height: r * 0.42), k.fill);
  // 짧은 날개 + 끝 눈덩이(쏘는 부위).
  final flip = k.wave(t, 2, 0.6) * 0.2;
  c
    ..save()
    ..translate(r * 0.15, -r * 0.05)
    ..rotate(-1.1 + flip);
  final flipper = Path()..addOval(Rect.fromCenter(center: Offset(0, -r * 0.22), width: r * 0.3, height: r * 0.5));
  // 날개 → 끝 눈덩이(쏘는 부위: 큰 흰 공 + 하늘 그늘).
  k
    ..blob(c, flipper, const Color(0xFF4A5680), const Color(0xFF1C2440), gloss: false)
    ..blob(
      c,
      Path()..addOval(Rect.fromCircle(center: Offset(0, -r * 0.56), radius: r * 0.22)),
      const Color(0xFFFFFFFF),
      const Color(0xFFBFE4FA),
    );
  c.restore();
  // 부리(앞).
  final beak = Path()
    ..moveTo(-r * 0.82, -r * 0.08)
    ..lineTo(-r * 1.2, r * 0.02)
    ..lineTo(-r * 0.82, r * 0.12)
    ..close();
  k
    ..blob(c, beak, const Color(0xFFFFB04A), const Color(0xFFE07A10), gloss: false, line: 0.6)
    ..eye(c, Offset(-r * 0.52, -r * 0.12), r * 0.28, look: -1)
    ..cheeks(c, Offset(-r * 0.5, r * 0.12), 0, r * 0.18);
  c.restore();
}

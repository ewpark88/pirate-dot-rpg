import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 날치(td_enemy:flyingfish — 폭풍 · 빠름 · 수면 · 원거리 물줄기): 길고 가는 파란 몸 + 큰 날개 지느러미 + 갈라진 꼬리,
/// 뒤로 잔상 줄(빠름 규칙). 쏘는 부위 = 입(앞 끝, 물빛 강조).
const flyingfish = HdSpecies(_flyingfish, extent: 1.25, muzzle: Offset(-0.86, 0.02));

void _flyingfish(HdKit k, Canvas c, double r, double t) {
  final flap = k.wave(t, 2);
  final bob = k.wave(t, 1, 0.5) * r * 0.05;
  // 빠름 규칙: 뒤로 잔상 줄 3개.
  for (final dy in const [-0.25, 0.05, 0.35]) {
    k.limb(
      c,
      Path()
        ..moveTo(r * 1.15, r * dy + bob)
        ..lineTo(r * 1.45, r * dy + bob),
      const Color(0xCCE8F8FF),
      r * 0.06,
    );
  }
  k.tail(c, Offset(r * 0.75, bob), r * 0.55, k.wave(t, 2, 0.4) * 0.2, const Color(0xFF4F8FE0), const Color(0xFF244F9A));
  c
    ..save()
    ..translate(0, bob);
  final body = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: r * 1.75, height: r * 0.8));
  k.blob(c, body, const Color(0xFF7FB8FF), const Color(0xFF2E5FB8));
  // 은빛 배 줄.
  k.fill.color = const Color(0x99FFFFFF);
  c.drawOval(Rect.fromCenter(center: Offset(-r * 0.05, r * 0.18), width: r * 1.2, height: r * 0.18), k.fill);
  // 날개 지느러미(몸 위로 크게 펼침, 펄럭).
  k.wing(
    c,
    Offset(-r * 0.25, -r * 0.1),
    r * 1.2,
    -0.75,
    (flap + 1) / 2,
    const Color(0xFFBEE8FF),
    const Color(0xFF5AAEE0),
  );
  // 입(쏘는 부위): 앞 끝 물빛 동그라미.
  k.fill.color = const Color(0xFFBFF4FF);
  c
    ..drawCircle(Offset(-r * 0.86, r * 0.02), r * 0.1, k.fill)
    ..drawCircle(Offset(-r * 0.86, r * 0.02), r * 0.1, k.ink);
  k.eye(c, Offset(-r * 0.5, -r * 0.1), r * 0.3, angry: true, look: -1);
  c.restore();
}

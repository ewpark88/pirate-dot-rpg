import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 용암게(td_enemy:lavacrab — 분열·수면·HP 2배·느림, docs/specs/economy-hd-monsters-b.md): 현무암 등딱지에 용암 금 3줄(쪼개질 자리),
/// 끝이 달아오른 큰 집게, 화난 눈. 옆걸음 들썩 + 금이 숨 쉬듯 밝았다 어두워짐.
const lavacrab = HdSpecies(_lavacrab, ground: 0.72);

void _lavacrab(HdKit k, Canvas c, double r, double t) => paintLavacrab(k, c, r, t, small: false);

const _rock = Color(0xFF8C7A86);
const _rockD = Color(0xFF3A2E38);
const _lava = Color(0xFFFF7A2A);
const _lavaHot = Color(0xFFFFE070);

/// 큰 것·작은 것(lavacrab_small.dart)이 같이 쓴다. 작은 것 = 금 없는 매끈한 등딱지·작은 집게·동그란 놀란 눈·빠른 종종걸음.
void paintLavacrab(HdKit k, Canvas c, double r, double t, {required bool small}) {
  final step = small ? 4 : 2; // 한 고리 걸음 수
  final bob = k.wave(t, step) * r * 0.06;
  final sway = k.wave(t, step ~/ 2) * r * 0.05; // 옆걸음
  final claw = k.wave(t, 1) * 0.22;
  final heat = (k.wave(t, 2) + 1) / 2;
  final hot = Color.lerp(_lava, _lavaHot, heat)!;
  c
    ..save()
    ..translate(sway, 0);
  // 1) 다리 3쌍
  for (final s in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final y = r * (0.25 + i * 0.18) + bob * 0.5;
      final lift = k.wave(t, step, i * 2.1 + s) * r * 0.06;
      k.limb(
        c,
        Path()
          ..moveTo(s * r * 0.6, y)
          ..quadraticBezierTo(s * r * 1.05, y - r * 0.12 + lift, s * r * 1.12, y + r * 0.22 + lift),
        _rockD,
        k.ink.strokeWidth * 1.1,
      );
    }
  }
  // 2) 집게(끝이 달아오름)
  final cs = small ? 0.7 : 1.0;
  for (final s in const [-1.0, 1.0]) {
    k.pincer(
      c,
      Offset(s * r * 0.82, -r * 0.5 + bob),
      r * cs,
      s * (0.35 + claw),
      Color.lerp(_rock, hot, 0.45)!,
      _rockD,
      open: 0.5 + claw * 2,
    );
  }
  // 3) 등딱지(넓은 타원 + 위 울퉁불퉁)
  final shell = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.15 + bob), width: r * 1.6, height: r * 1.05));
  k.blob(c, shell, small ? const Color(0xFFA8949E) : _rock, _rockD);
  // 4) 용암 금 3줄(큰 것만)
  if (!small) {
    // 짧은 번개꼴 금 3(등 위쪽에서 바깥으로) — 쪼개질 자리.
    for (final (x, y, dx) in const [(-0.5, 0.05, -0.16), (0.0, 0.35, 0.0), (0.5, 0.05, 0.16)]) {
      final top = Offset(r * x * 0.4, r * (y - 0.18) + bob);
      final mid = Offset(r * (x * 0.75 + 0.06), r * y + bob);
      final low = Offset(r * (x + dx), r * (y + 0.16) + bob);
      k.limb(
        c,
        Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(mid.dx, mid.dy)
          ..lineTo(low.dx, low.dy),
        hot,
        k.ink.strokeWidth * 0.85,
      );
    }
  } else {
    k.spots(c, r, [(-0.35, 0.05, 0.07), (0.3, 0.25, 0.06), (0.05, 0.4, 0.05)], const Color(0x55FF9A4A));
  }
  // 5) 얼굴: 눈자루 + 눈(큰 것 = 화남, 작은 것 = 동그란 놀람), 입
  for (final s in const [-1.0, 1.0]) {
    c.drawLine(Offset(s * r * 0.22, -r * 0.25 + bob), Offset(s * r * 0.28, -r * 0.5 + bob), k.ink);
    k.eye(
      c,
      Offset(s * r * 0.28, -r * 0.58 + bob),
      r * (small ? 0.36 : 0.32),
      angry: !small,
      look: small ? 0 : -s * 0.3,
    );
  }
  if (small) {
    k.fill.color = const Color(0xFF6A1424);
    c
      ..drawOval(Rect.fromCenter(center: Offset(0, r * 0.3 + bob), width: r * 0.16, height: r * 0.2), k.fill)
      ..drawOval(Rect.fromCenter(center: Offset(0, r * 0.3 + bob), width: r * 0.16, height: r * 0.2), k.ink);
  } else {
    c.drawPath(
      Path()
        ..moveTo(-r * 0.16, r * 0.34 + bob)
        ..quadraticBezierTo(0, r * 0.24 + bob, r * 0.16, r * 0.34 + bob),
      k.ink,
    );
  }
  c.restore();
}

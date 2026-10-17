import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_v2.dart';

/// 거대 크라켄(대보스 td_boss:kraken_titan): 붉은 거인 문어 — 굵은 촉수 8가닥이 물결치며 끝이 말리고, 금빛 눈이 노려본다.
/// 시범 크라켄(보라·금관)과 달리 흉터·뾰족 머리·빨판 줄로 더 사납게. HD v2: 머리 점무늬 링·림 라이트·이중 광택,
/// 표정: 평소 / 공격 예고(촉수 번쩍 쳐들기·붉게 타는 눈·입 활짝) / 쓰러짐(촉수 축 늘어짐·소용돌이 눈·기우뚱·별).
const krakenTitan = HdSpecies(_krakenTitan, extent: 1.55, ground: 0.95);

void _krakenTitan(HdKit k, Canvas c, double r, double t) {
  const red = Color(0xFFFF5A5A);
  const redD = Color(0xFF9A1E32);
  final wind = k.mood == HdMood.windup;
  final down = k.mood == HdMood.down;
  final breathe = 1 + k.wave(t, wind ? 2 : 1) * (wind ? 0.05 : 0.035);
  if (down) k.downTilt(c, r * 0.9, t);
  // 촉수 8: 양옆으로 크게 뻗고 끝이 말린다(뒤 4 → 앞 4)
  for (final front in const [false, true]) {
    for (var i = 0; i < 4; i++) {
      for (final s in const [-1.0, 1.0]) {
        final a = front ? math.pi * (0.3 + i * 0.1) : math.pi * (0.92 + i * 0.16);
        // 예고: 촉수를 위로 크게 쳐든다, 쓰러짐: 축 늘어져 거의 안 움직인다
        final wig = k.wave(t, 1, i * 1.3 + s) * (down ? 0.05 : 0.22) + (wind ? -0.45 : (down ? 0.25 : 0));
        final from = Offset(s * r * 0.35, r * 0.3);
        final reach = r * (front ? 1.05 : 1.3);
        final mid = from + Offset(s * math.cos(a - wig) * reach * 0.6, math.sin(a - wig) * reach * 0.5);
        final end = from + Offset(s * math.cos(a + wig) * reach, math.sin(a + wig) * reach * 0.75 + r * 0.25);
        final curl = end + Offset(s * r * 0.12, -r * 0.14);
        final p = Path()
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy)
          ..quadraticBezierTo(curl.dx + s * r * 0.08, curl.dy + r * 0.12, curl.dx, curl.dy);
        k.limb(c, p, front ? red : const Color(0xFFE04050), r * (front ? 0.26 : 0.22));
        if (front) {
          // 빨판 줄(앞 촉수만)
          k.fill.color = const Color(0xFFFFD0D8);
          for (var j = 1; j <= 3; j++) {
            final u = j / 4;
            final q = Offset.lerp(Offset.lerp(from, mid, u), Offset.lerp(mid, end, u), u)!;
            c.drawCircle(q + Offset(0, r * 0.06), r * 0.045, k.fill);
          }
        }
      }
    }
  }
  c
    ..save()
    ..translate(0, r * 0.4)
    ..scale(breathe, 2 - breathe)
    ..translate(0, -r * 0.4);
  // 뾰족한 머리(망토)
  final head = Path()
    ..moveTo(-r * 0.78, r * 0.42)
    ..cubicTo(-r * 1.0, -r * 0.6, -r * 0.4, -r * 1.25, 0, -r * 1.42)
    ..cubicTo(r * 0.4, -r * 1.25, r * 1.0, -r * 0.6, r * 0.78, r * 0.42)
    ..quadraticBezierTo(0, r * 0.62, -r * 0.78, r * 0.42)
    ..close();
  k
    ..blob(c, head, const Color(0xFFFF9A8A), redD)
    ..spots(c, r, const [
      (-0.4, -0.6, 0.11),
      (0.45, -0.35, 0.09),
      (0.1, -1.0, 0.08),
      (-0.15, -0.3, 0.05),
    ], const Color(0x66901830));
  // 흉터(X)
  final scar = Offset(r * 0.38, -r * 0.72);
  c
    ..drawLine(scar + Offset(-r * 0.12, -r * 0.1), scar + Offset(r * 0.12, r * 0.1), k.ink)
    ..drawLine(scar + Offset(r * 0.12, -r * 0.1), scar + Offset(-r * 0.12, r * 0.1), k.ink);
  // 금빛 눈(세로 동공) — 화남
  for (final s in const [-1.0, 1.0]) {
    final at = Offset(s * r * 0.34, -r * 0.15);
    if (down) {
      k.dizzyEye(c, at, r * 0.4, t * s);
      continue;
    }
    final white = Rect.fromCenter(center: at, width: r * 0.42, height: r * 0.4);
    k.fill.color = const Color(0xFFFFD84A);
    c
      ..drawOval(white, k.fill)
      ..drawOval(white, k.ink);
    k.fill.color = HdKit.inkColor;
    c.drawOval(Rect.fromCenter(center: at + Offset(-r * 0.03, 0), width: r * 0.1, height: r * 0.3), k.fill);
    k.fill.color = const Color(0xFFFFFFFF);
    c
      ..drawCircle(at + Offset(-r * 0.09, -r * 0.08), r * 0.05, k.fill)
      ..drawLine(at + Offset(-s * r * 0.26, -r * 0.32), at + Offset(s * r * 0.2, -r * 0.18), k.ink);
    if (wind) k.angerEye(c, at, r * 0.42);
  }
  // 이빨 입(크게 으르렁)
  final open = wind ? r * 0.2 : (down ? r * 0.02 : (k.wave(t, 1, 0.5) + 1) * r * 0.04);
  k.mouth(
    c,
    Path()
      ..moveTo(-r * 0.36, r * 0.16)
      ..quadraticBezierTo(0, r * 0.05, r * 0.36, r * 0.16)
      ..quadraticBezierTo(0, r * 0.5 + open, -r * 0.36, r * 0.16)
      ..close(),
  );
  for (var i = 0; i < 4; i++) {
    k.tooth(c, Offset(-r * 0.28 + i * r * 0.14, r * 0.12), r * 0.12, r * 0.13);
  }
  c.restore();
  if (down) {
    k.dizzyStars(c, Offset(0, -r * 1.6), r, t);
    c.restore();
  }
}

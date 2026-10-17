import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 빙산 바다코끼리(해역 보스 td_boss:iceberg_walrus): 육각 얼음덩이에 반쯤 갇힌 갈색 바다코끼리 — 긴 상아·수염,
/// 얼음 속에서 씩씩대며 몸을 들썩이고 얼음 면이 반짝인다.
const icebergWalrus = HdSpecies(_icebergWalrus, extent: 1.45, ground: 0.95);

/// 크라켄 촉수(td_boss:kraken_tentacle): 물에서 솟아 휘감는 보라 촉수 하나 — 빨판 줄, 끝이 말렸다 펴진다.
const krakenTentacle = HdSpecies(_krakenTentacle, ground: 1);

void _icebergWalrus(HdKit k, Canvas c, double r, double t) {
  const brown = Color(0xFFC08A5A);
  const brownD = Color(0xFF6A3E22);
  final heave = k.wave(t, 1) * r * 0.04;
  // 얼음덩이 뒤판(육각)
  final ice = Path();
  for (var i = 0; i < 6; i++) {
    final a = math.pi / 6 + i * math.pi / 3;
    final p = Offset(math.cos(a) * r * 1.15, math.sin(a) * r * 1.0 + r * 0.05);
    i == 0 ? ice.moveTo(p.dx, p.dy) : ice.lineTo(p.dx, p.dy);
  }
  ice.close();
  k.fill.color = const Color(0xFFDDF4FF);
  // 몸통(얼음 속 — 들썩)
  c
    ..drawPath(ice, k.fill)
    ..save()
    ..translate(0, heave);
  for (final s in const [-1.0, 1.0]) {
    k.blob(
      c,
      Path()..addOval(Rect.fromCenter(center: Offset(s * r * 0.72, r * 0.25), width: r * 0.42, height: r * 0.26)),
      brown,
      brownD,
      gloss: false,
    );
  }
  final body = Path()
    ..moveTo(0, -r * 0.7)
    ..cubicTo(r * 0.75, -r * 0.7, r * 0.8, r * 0.7, 0, r * 0.75)
    ..cubicTo(-r * 0.8, r * 0.7, -r * 0.75, -r * 0.7, 0, -r * 0.7)
    ..close();
  k.blob(c, body, const Color(0xFFE0AE7E), brownD);
  // 주둥이(볼록 두 덩이) + 코 + 수염 + 상아
  for (final s in const [-1.0, 1.0]) {
    k.blob(
      c,
      Path()..addOval(Rect.fromCenter(center: Offset(s * r * 0.15, -r * 0.05), width: r * 0.36, height: r * 0.3)),
      const Color(0xFFF0C89A),
      brownD,
      gloss: false,
      line: 0.7,
    );
  }
  for (final s in const [-1.0, 1.0]) {
    k.blob(
      c,
      Path()
        ..moveTo(s * r * 0.12, r * 0.05)
        ..quadraticBezierTo(s * r * 0.16, r * 0.45, s * r * 0.1, r * 0.62)
        ..quadraticBezierTo(s * r * 0.06, r * 0.42, s * r * 0.03, r * 0.08)
        ..close(),
      const Color(0xFFFFFCF0),
      const Color(0xFFD8CCB0),
      gloss: false,
      line: 0.6,
    );
  }
  k.spots(c, r, const [(0.0, -0.18, 0.06)], HdKit.inkColor);
  final w = k.ink.strokeWidth;
  k.ink.strokeWidth = w * 0.4;
  for (final s in const [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(s * r * 0.2, -r * 0.02 + i * r * 0.05), Offset(s * r * 0.42, -r * 0.06 + i * r * 0.08), k.ink);
    }
  }
  k.ink.strokeWidth = w;
  for (final s in const [-1.0, 1.0]) {
    k.eye(c, Offset(s * r * 0.24, -r * 0.4), r * 0.26, angry: true);
  }
  // 씩씩 콧김(고리마다 한 번)
  final puff = (k.wave(t, 1, -1) + 1) / 2;
  if (puff > 0.4) {
    k.fill.color = Color.fromRGBO(255, 255, 255, (puff - 0.4) / 0.6 * 0.8);
    for (final s in const [-1.0, 1.0]) {
      c.drawCircle(Offset(s * r * (0.35 + puff * 0.15), -r * 0.15), r * 0.06 * puff, k.fill);
    }
  }
  c.restore();
  // 얼음 앞면: 반투명 판 + 외곽선 + 금 + 반짝(고리 따라 이동)
  k.fill.color = const Color(0x5590D4FF);
  c
    ..drawPath(ice, k.fill)
    ..drawPath(ice, k.ink);
  k.ink.strokeWidth = w * 0.45;
  c
    ..drawLine(Offset(-r * 0.95, -r * 0.2), Offset(-r * 0.6, r * 0.15), k.ink)
    ..drawLine(Offset(r * 0.7, -r * 0.75), Offset(r * 0.5, -r * 0.45), k.ink);
  k.ink.strokeWidth = w;
  final gl = t / HdKit.loopMs;
  k.fill.color = const Color(0xCCFFFFFF);
  c.drawPath(
    Path()
      ..moveTo(-r * 0.9 + gl * r * 1.4, -r * 0.85)
      ..lineTo(-r * 0.75 + gl * r * 1.4, -r * 0.85)
      ..lineTo(-r * 1.0 + gl * r * 1.4, -r * 0.3)
      ..lineTo(-r * 1.1 + gl * r * 1.4, -r * 0.3)
      ..close(),
    k.fill,
  );
}

void _krakenTentacle(HdKit k, Canvas c, double r, double t) {
  const purple = Color(0xFFB062FF);
  final sway = k.wave(t, 1) * r * 0.25;
  final curl = k.wave(t, 1, 1);
  final tip = Offset(sway + r * 0.35, -r * 1.05);
  final p = Path()
    ..moveTo(0, r * 0.95)
    ..cubicTo(-r * 0.45, r * 0.3, sway + r * 0.4, -r * 0.3, tip.dx, tip.dy)
    ..quadraticBezierTo(tip.dx + r * 0.25, tip.dy + r * (0.15 + curl * 0.1), tip.dx + r * 0.08, tip.dy + r * 0.28);
  // 굵기를 아래 → 위로 가늘게: 세 겹을 길이별로
  for (final m in p.computeMetrics()) {
    final segs = [(0.0, 1.0, 0.42), (0.0, 0.7, 0.55), (0.0, 0.4, 0.68)];
    for (final (a, b, wd) in segs) {
      k.limb(c, m.extractPath(m.length * a, m.length * b), purple, r * wd * 0.6);
    }
    // 빨판(안쪽 줄)
    k.fill.color = const Color(0xFFFFC8F0);
    for (var i = 1; i < 8; i++) {
      final tg = m.getTangentForOffset(m.length * i / 9);
      if (tg == null) continue;
      final n = Offset(-tg.vector.dy, tg.vector.dx);
      final rad = r * (0.09 - i * 0.008);
      c
        ..drawCircle(tg.position + n * r * 0.12, rad, k.fill)
        ..drawCircle(tg.position + n * r * 0.12, rad, k.ink..strokeWidth *= 0.4);
      k.ink.strokeWidth /= 0.4;
    }
  }
  // 물 고리
  k.fill.color = const Color(0xCCE8F8FF);
  c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.95), width: r * 1.2, height: r * 0.26), k.fill);
}

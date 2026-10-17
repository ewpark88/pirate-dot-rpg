import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// 거품 붓(재사용).
final _bubble = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..color = const Color(0xCCE8F8FF);

/// HdKit 부품 더하기(S5 — 바닷새 날개 · 가시 고리 · 수중 거품). 모든 종이 같이 쓴다(render-hd-style.md 6절 4).
extension HdKitParts on HdKit {
  /// 날개(옆모습, 몸 뒤로 들린 한 장 — S5 바닷새): 어깨 [at], 길이 [len], [lift](-0.4 내림 ~ 0.6 올림, wave로 날갯짓),
  /// [bend](0 둥근 날개 ~ 1 가운데가 꺾인 뾰족 날개), 끝 깃 색 [tip]·[tipDark].
  void wing(
    Canvas c,
    Offset at,
    double len,
    double lift,
    Color light,
    Color dark, {
    Color? tip,
    Color? tipDark,
    double bend = 0,
  }) {
    final top = Offset(at.dx + len * 0.55, at.dy - len * (0.55 + lift * 0.6 + bend * 0.2));
    final end = Offset(at.dx + len, at.dy - len * (0.3 + lift * 0.7 - bend * 0.15));
    final p = Path()
      ..moveTo(at.dx, at.dy)
      ..quadraticBezierTo(top.dx - len * bend * 0.1, top.dy, end.dx, end.dy)
      ..quadraticBezierTo(at.dx + len * 0.65, at.dy - len * (0.05 + lift * 0.3), at.dx + len * 0.2, at.dy + len * 0.12)
      ..close();
    blob(c, p, light, dark, gloss: false);
    if (tip == null) return;
    // 끝 깃: 날개 끝 1/3을 덧칠.
    final mid = Offset.lerp(top, end, 0.45)!;
    final q = Path()
      ..moveTo(mid.dx, mid.dy)
      ..lineTo(end.dx, end.dy)
      ..quadraticBezierTo(
        at.dx + len * 0.78,
        at.dy - len * (0.12 + lift * 0.4),
        at.dx + len * 0.62,
        at.dy - len * (0.1 + lift * 0.35),
      )
      ..close();
    blob(c, q, tip, tipDark ?? dark, gloss: false, line: 0.7);
  }

  /// 가시 고리(성게·복어): 가운데에서 [n]개, 몸 [inner]에서 [outer]까지(r 배수), 굵기 [w], 끝 색 [tipColor].
  /// [hot]번째 가시는 쏘는 부위 — 밝은 색 + 큰 끝(원거리 규칙). [spin]은 라디안 돌림(wave로 흔들기).
  void spikes(
    Canvas c,
    double r,
    int n,
    double inner,
    double outer,
    double w,
    Color light,
    Color dark,
    Color tipColor, {
    int? hot,
    double spin = 0,
    double squash = 0.85,
  }) {
    for (var i = 0; i < n; i++) {
      final a = spin + i * 2 * math.pi / n;
      final d = Offset(math.cos(a), math.sin(a) * squash);
      final side = Offset(-d.dy, d.dx) * (r * w);
      final base = d * (r * inner);
      final p = Path()
        ..moveTo(base.dx + side.dx, base.dy + side.dy)
        ..lineTo(d.dx * r * outer, d.dy * r * outer)
        ..lineTo(base.dx - side.dx, base.dy - side.dy)
        ..close();
      final isHot = i == hot;
      blob(
        c,
        p,
        isHot ? const Color(0xFFFFF6B0) : light,
        isHot ? const Color(0xFFFFC23A) : dark,
        gloss: false,
        line: 0.7,
      );
      fill.color = isHot ? const Color(0xFFFFFFFF) : tipColor;
      c.drawCircle(d * (r * outer * 0.96), r * (isHot ? 0.09 : 0.055), fill);
    }
  }

  /// 수중 거품(물속 종): 몸 위로 오르는 작은 고리 3개 — 고리마다 한 번 올라 이어진다.
  void bubbles(Canvas c, double r, double t, {double x = 0}) {
    _bubble.strokeWidth = math.max(1.5, r * 0.05);
    for (var i = 0; i < 3; i++) {
      final up = ((t / HdKit.loopMs + i / 3) % 1) * r * 0.7;
      c.drawCircle(Offset(x + r * (0.35 - i * 0.3), -r * 0.75 - up), r * (0.07 + i * 0.025), _bubble);
    }
  }
}

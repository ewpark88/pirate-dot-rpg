import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/top/top_ultimate.dart';

/// 계열별 고유 필살기(S1 핵앤슬래시): 계열 11종 × 0.2·0.5·0.8 한 장 시안(마지막 줄은 신화 — 무지개·금 테).
/// 배 자리(갈색 타원)는 맨 위에 그려 늘 또렷한지 본다.
void main() {
  testWidgets('계열 필살기 한 장', (tester) async {
    const fams = [
      'pierce',
      'laser',
      'underwater',
      'shock',
      'lob',
      'cluster',
      'assault',
      'direct',
      'skip',
      'air',
      'ring',
    ];
    const cellW = 160.0;
    const cellH = 220.0;
    const ts = [0.2, 0.5, 0.8];
    final size = Size(cellW * ts.length, cellH * (fams.length + 1));
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(painter: _Sheet(fams, ts, cellW, cellH)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_ultimate.png'));
  });
}

class _Sheet extends CustomPainter {
  _Sheet(this.fams, this.ts, this.w, this.h);
  final List<String> fams;
  final List<double> ts;
  final double w;
  final double h;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2E86C8));
    final rows = [...fams, 'lob'];
    for (final (r, fam) in rows.indexed) {
      for (final (i, t) in ts.indexed) {
        canvas
          ..save()
          ..translate(i * w, r * h)
          ..clipRect(Rect.fromLTWH(0, 0, w, h))
          ..translate(w / 2, h * 0.8)
          ..scale(w / (2 * TopUltimate.half + 40));
        TopUltimate()
          ..start(fam, Offset.zero, 0, rarity: r == fams.length ? 5 : 3)
          ..paint(canvas, t * TopUltimate.lifeMs, lite: false);
        canvas
          ..drawOval(
            Rect.fromCenter(center: Offset.zero, width: 26, height: 48),
            Paint()..color = const Color(0xFF9A5A2A),
          )
          ..restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

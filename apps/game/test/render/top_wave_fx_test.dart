import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/top/top_wave_fx.dart';

/// 탑다운 해일 견본 (S1 '해일 쐐기가 네모로 잘려 보인다'): 옆모습 그림 tidal_wave 대신 위에서 본 물 —
/// 제자리 스킬(퍼지는 물 고리 30%·70%)과 움직이는 궁극기(진행 방향 볼록한 물 벽 + 거품 자국). 단위 1 = 4px.
class _Sheet extends CustomPainter {
  final fx = TopWaveFx();

  Effect _e(double x, double y, double t, {double vx = 0}) => Effect()
    ..sheetId = 'tidal_wave'
    ..x = x
    ..y = y
    ..frames = 8
    ..frameMs = 100
    ..ageMs = t * 800
    ..vx = vx;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A7FCC))
      ..scale(4);
    fx
      ..paint(canvas, _e(30, 30, 0.3))
      ..paint(canvas, _e(90, 30, 0.7))
      ..paint(canvas, _e(70, 110, 0.4, vx: 0.2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  testWidgets('해일 견본 골든', (tester) async {
    tester.view
      ..physicalSize = const Size(520, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(width: 520, height: 640, child: CustomPaint(painter: _Sheet())),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_wave_fx.png'));
  });
}

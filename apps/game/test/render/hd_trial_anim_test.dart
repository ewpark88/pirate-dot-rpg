import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_cartoon.dart';

/// HD 카툰 시범 움직임 증거(사용자 승인 시 보여 줄 것): 4종 × 0.1초 간격 8장 — 숨쉬기·집게 까딱·촉수 꿈틀·꼬리 흔들기.
void main() {
  testWidgets('HD 카툰 애니메이션 띠(0.1초 × 8)', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 840)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const Center(
        child: RepaintBoundary(
          child: SizedBox(width: 1600, height: 840, child: CustomPaint(painter: _Strip())),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_trial_anim.png'));
  });
}

class _Strip extends CustomPainter {
  const _Strip();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E3550));
    final hd = HdCartoon();
    for (final (row, kind) in HdCartoon.kinds.indexed) {
      for (var f = 0; f < 8; f++) {
        canvas
          ..save()
          ..translate(100 + f * 200.0, 105 + row * 210.0);
        hd.paint(canvas, kind, kind == 'kraken' ? 62 : 46, f * 100.0);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

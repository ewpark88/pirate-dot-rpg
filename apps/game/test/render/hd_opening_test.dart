import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_opening.dart';

/// 오프닝 5컷 배경(S4 _CutArt 바탕) — 폰 크기 5장 나란히(멈춘 그림).
void main() {
  testWidgets('오프닝 5컷 배경 한 장', (tester) async {
    const size = Size(5 * 240.0, 426);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            child: SizedBox.fromSize(
              size: size,
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    SizedBox(width: 240, height: 426, child: HdOpeningBackdrop(cut: i, animate: false)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_opening.png'));
  });
}

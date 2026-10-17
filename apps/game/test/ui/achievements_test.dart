import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';

import 'ui_harness.dart';

// 업적 시트 (계약 ui-achievements 전 임시 어댑터): 항해 탭 '업적' 버튼 → 목록 · 닿은 단계면 [받기](금빛) · 빨간 점.

void main() {
  testWidgets('최고 스테이지 80 → "먼 바다로" 1단계(20) 받을 수 있음 · 버튼 빨간 점', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(
      tester,
      s.copyWith(progress: s.progress.copyWith(bestStage: 80)),
      size: const Size(400, 1600),
    );
    expect(find.byKey(const Key('ach.dot')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ach.open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ach.sheet')), findsOneWidget);
    expect(tester.widget<SkinButton>(find.byKey(const Key('ach.claim.stage'))).onPressed, isNotNull);
    expect(tester.widget<SkinButton>(find.byKey(const Key('ach.claim.rebirths'))).onPressed, isNull);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in const [('360', Size(360, 640), 3.0), ('tablet', Size(800, 1280), 2.0)]) {
      testWidgets('업적 시트 ko $name', (tester) async {
        final s = loadFixture('stage37_midgame');
        await pumpGame(
          tester,
          s.copyWith(progress: s.progress.copyWith(bestStage: 80, rebirths: 2)),
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
        );
        await tester.tap(find.byKey(const Key('ach.open')));
        await tester.pumpAndSettle();
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_achievements_$name.png'));
      });
    }
  });
}

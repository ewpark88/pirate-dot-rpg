import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/text/outline_digits.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';

import 'ui_harness.dart';

/// 테두리 글자(디자인 개편 공용 부품): 숫자만이면 아틀라스, 그 밖은 두 겹 TextStyle, fit이면 칸에 맞춰 줄임.
void main() {
  late OutlineDigits atlas;

  setUpAll(() async {
    await loadGoldenFonts();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    atlas = (await tester.runAsync(() => OutlineDigits.load(bundle: rootBundle, devicePixelRatio: 2)))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [outlineDigitsProvider.overrideWith((ref, dpr) async => atlas)],
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF2B2F5C),
            body: Center(child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  test('숫자만인가: 0~9·K·M·B·T·%·/·+·×·.·,·-·:·공백만', () {
    expect(isOutlineDigits('12.5K'), isTrue);
    expect(isOutlineDigits('+300 / 1.2M'), isTrue);
    expect(isOutlineDigits('Lv 3'), isFalse);
    expect(isOutlineDigits('보스'), isFalse);
    expect(isOutlineDigits(''), isFalse);
  });

  testWidgets('숫자는 아틀라스(CustomPaint, 폭 = measure), 글자는 테 + 채움 두 겹 Text', (tester) async {
    await pump(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [OutlineText('12.5K', size: 20), OutlineText('보스 처치!', size: 20)],
      ),
    );
    final box = tester.getSize(find.byType(CustomPaint).last);
    final h = atlas.layout.heightFor(20);
    expect(box, Size(atlas.layout.measure('12.5K', height: h), h));
    final texts = tester.widgetList<Text>(find.text('보스 처치!')).toList();
    expect(texts, hasLength(2));
    expect(texts.first.style!.foreground!.style, PaintingStyle.stroke);
    expect(texts.first.style!.foreground!.strokeWidth, closeTo(20 * strokeRatio * 2, 1e-4));
    expect(texts.last.style!.color, OutlineTone.white.color);
  });

  testWidgets('fit: 좁은 칸에서도 넘치지 않는다(FittedBox scaleDown)', (tester) async {
    await pump(tester, const SizedBox(width: 40, child: OutlineText('999,999,999', size: 28, fit: true)));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FittedBox)).width, lessThanOrEqualTo(40));
  });

  testWidgets('골든: 4색 숫자 + 한글', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 220));
    await pump(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          OutlineText('12.5K', size: 28),
          OutlineText('+300', size: 24, tone: OutlineTone.green),
          OutlineText('-1.2M', size: 24, tone: OutlineTone.red),
          OutlineText('×3 100%', size: 22, tone: OutlineTone.gold),
          OutlineText('보스 처치!', size: 22, tone: OutlineTone.gold),
        ],
      ),
    );
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/outline_text.png'));
    await tester.binding.setSurfaceSize(null);
  });
}

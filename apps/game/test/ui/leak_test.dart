import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

// 메모리 누수 점검 (S1 2026-10-18 — 폰 PSS가 30분에 2배): 시트를 200번 열고 닫고, 탭을 200번 오간 뒤
// 위젯(요소) 수·살아 있는 이미지 수가 처음과 같아야 한다(남는 컨트롤러·구독·그림이 없게).

int _elements(WidgetTester tester) => tester.allElements.length;

void main() {
  testWidgets('시트 열고 닫기 200번 · 탭 오가기 200번 뒤 요소·이미지 수 그대로', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), openTab: false);
    await tester.pumpAndSettle();
    // 한 바퀴 돌려 처음 그림을 다 읽어 둔다(첫 디코드는 누수가 아님).
    for (final tab in ['tab.2', 'tab.1', 'tab.3', 'tab.0']) {
      await tester.tap(find.byKey(Key(tab)).first);
      await tester.pumpAndSettle();
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final cache = PaintingBinding.instance.imageCache;
    final e0 = _elements(tester);
    final live0 = cache.liveImageCount;
    for (var i = 0; i < 200; i++) {
      await tester.tap(find.byKey(const Key('tab.2')).first);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab.1')).first);
    await tester.pumpAndSettle();
    for (var i = 0; i < 200; i++) {
      final tab = ['tab.2', 'tab.1', 'tab.3', 'tab.0'][i % 4];
      await tester.tap(find.byKey(Key(tab)).first);
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final e1 = _elements(tester);
    final live1 = cache.liveImageCount;
    debugPrint('LEAK elements $e0 → $e1 · live images $live0 → $live1 · cache ${cache.currentSize}');
    expect(e1, lessThanOrEqualTo(e0 + 5), reason: '요소가 쌓인다');
    expect(live1, lessThanOrEqualTo(live0 + 2), reason: '이미지가 쌓인다');
  });
}

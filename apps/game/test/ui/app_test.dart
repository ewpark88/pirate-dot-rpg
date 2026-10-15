import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

void main() {
  for (final (locale, tab) in [(const Locale('ko'), '항해'), (const Locale('en'), 'Voyage')]) {
    testWidgets('${locale.languageCode}: 탭 4개', (tester) async {
      await pumpGame(tester, loadFixture('new_player'), locale: locale);
      expect(find.text(tab), findsOneWidget);
      // 도크 아이콘 4개 (시트 안 도크).
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('tab.$i')), findsOneWidget);
      }
    });
  }
}

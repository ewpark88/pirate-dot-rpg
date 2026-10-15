import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/pixel/pixel_tab_bar.dart';

import 'ui_harness.dart';

void main() {
  for (final (locale, tab) in [(const Locale('ko'), '항해'), (const Locale('en'), 'Voyage')]) {
    testWidgets('${locale.languageCode}: 탭 4개', (tester) async {
      await pumpGame(tester, loadFixture('new_player'), locale: locale);
      expect(find.text(tab), findsOneWidget);
      expect(find.byType(PixelTabItem), findsNWidgets(4));
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/app.dart';

void main() {
  for (final (locale, title, tab) in [
    (const Locale('ko'), '해적도트 원정대', '항해'),
    (const Locale('en'), 'Pirate Dot Expedition', 'Voyage'),
  ]) {
    testWidgets('${locale.languageCode}: 제목과 탭 4개', (tester) async {
      await tester.pumpWidget(PirateDotApp(locale: locale));
      await tester.pump();
      expect(find.text(title), findsOneWidget);
      expect(find.text(tab), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
    });
  }
}

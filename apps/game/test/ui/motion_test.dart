import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/skin/rolling_text.dart';

// 모션 기준 #50 (S1 2026-10-17): 숫자 롤링 — 바뀌면 옛 글이 위로 빠지고 새 글이 아래에서 올라온다.

Widget _host(String text, {bool calm = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: calm),
    child: Center(child: RollingText(text, textKey: const Key('roll'))),
  ),
);

void main() {
  testWidgets('값이 바뀌면 잠깐 두 글(옛·새)이 겹쳐 굴러가고, 끝나면 새 글 하나', (tester) async {
    await tester.pumpWidget(_host('29.3K'));
    await tester.pumpWidget(_host('31.0K'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('roll')), findsNWidgets(2));
    await tester.pump(rollFor);
    expect(find.text('31.0K'), findsOneWidget);
    expect(find.text('29.3K'), findsNothing);
  });

  testWidgets('애니메이션 끄기면 바로 바뀐다', (tester) async {
    await tester.pumpWidget(_host('1', calm: true));
    await tester.pumpWidget(_host('2', calm: true));
    await tester.pump();
    expect(find.byKey(const Key('roll')), findsOneWidget);
  });
}

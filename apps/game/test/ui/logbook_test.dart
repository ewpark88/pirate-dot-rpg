import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';

import 'ui_harness.dart';

// 항해 기록 (S1 2026-10-18): 칭호 띠 옆 책 버튼 → 큰 숫자 카드. 값은 경제 achievementValue 그대로, 러시 기록이 없으면 그 칸은 없다.

final _t = GameTables.load();

void main() {
  testWidgets('책 버튼 → 기록 카드 · 최고 스테이지 값 = achievementValue · 러시 기록 없으면 칸 없음', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s);
    expect(find.byType(VoyageTab), findsOneWidget);
    await tester.tap(find.byKey(const Key('logbook.open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logbook.sheet')), findsOneWidget);
    final best = achievementValue(s, _t, 'bestStage')!;
    expect(
      find.descendant(of: find.byKey(const Key('logbook.bestStage')), matching: find.text('$best')),
      findsWidgets,
    );
    if (s.rush?.bestTicks == null) expect(find.byKey(const Key('logbook.rushBest')), findsNothing);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in const [('360', Size(360, 640), 3.0), ('tablet', Size(800, 1280), 2.0)]) {
      testWidgets('항해 기록 ko $name', (tester) async {
        await pumpGame(tester, loadFixture('stage37_midgame'), size: size, dpr: dpr, locale: const Locale('ko'));
        await tester.tap(find.byKey(const Key('logbook.open')));
        await tester.pumpAndSettle();
        await precacheImages(tester);
        await tester.pump();
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_logbook_$name.png'));
      });
    }
  });
}

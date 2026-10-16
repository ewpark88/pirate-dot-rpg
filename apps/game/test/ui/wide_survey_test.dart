import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

// 태블릿·폴드 가로폭 최종 점검 (S1 2026-10-16): 시트·창마다 빈 공간·너무 큰 글자·좌우 여백을 골든으로 본다.

const List<(String, Size, double)> _wide = [
  ('tablet', Size(800, 1280), 2.0),
  // 폴드 펼침(세로) — 거의 정사각.
  ('fold', Size(717, 853), 2.4),
];

void main() {
  setUpAll(loadGoldenFonts);

  for (final (name, size, dpr) in _wide) {
    for (final (tabName, tab) in [('voyage', voyageTab), ('ship', shipTab), ('crew', crewTab), ('summon', summonTab)]) {
      testWidgets('넓은 화면 $name · $tabName 탭', (tester) async {
        await pumpGame(
          tester,
          loadFixture('stage37_midgame'),
          tab: tab,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
          fullSheet: true,
        );
        await precacheImages(tester);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_wide_${name}_$tabName.png'));
      });
    }

    testWidgets('넓은 화면 $name · 설정', (tester) async {
      await pumpGame(
        tester,
        loadFixture('stage37_midgame'),
        size: size,
        dpr: dpr,
        locale: const Locale('ko'),
        openTab: false,
      );
      await tester.tap(find.byKey(const Key('hud.settings')));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_wide_${name}_settings.png'));
    });

    testWidgets('넓은 화면 $name · 퀘스트·출석', (tester) async {
      await pumpGame(
        tester,
        loadFixture('stage37_midgame'),
        size: size,
        dpr: dpr,
        locale: const Locale('ko'),
        openTab: false,
      );
      await tester.tap(find.byKey(const Key('daily.icon')));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_wide_${name}_daily.png'));
    });
  }
}

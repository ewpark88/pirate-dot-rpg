import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

/// 유동 크기 (AGENTS): 기기 4종(360·S24·411·태블릿 800)에서 넘침 없음 + 골든.
const List<(String, Size, double)> _devices = [
  ('s24', s24Size, s24Dpr),
  ('360', Size(360, 640), 3.0),
  ('411', Size(411, 891), 2.625),
  // 태블릿 세로 (AGENTS 유동 크기, 2026-10-15).
  ('tab', Size(800, 1280), 2.0),
];

void main() {
  setUpAll(loadGoldenFonts);

  for (final (name, size, dpr) in _devices) {
    for (final locale in const [Locale('ko'), Locale('en')]) {
      testWidgets('$name ${locale.languageCode}: 샘플 3개 × 탭 4개가 넘치지 않는다', (tester) async {
        for (final fixture in ['stage37_midgame', 'boss_fight', 'all_crews_mythic']) {
          for (final tab in [voyageTab, shipTab, crewTab, summonTab]) {
            await pumpGame(tester, loadFixture(fixture), locale: locale, tab: tab, size: size, dpr: dpr);
            expect(tester.takeException(), isNull, reason: '$fixture tab $tab');
          }
        }
      });
    }

    // S24는 기존 탭 골든(기본 크기)이 맡는다.
    if (name == 's24') continue;
    for (final (tabName, tab) in [('voyage', voyageTab), ('ship', shipTab), ('crew', crewTab), ('summon', summonTab)]) {
      testWidgets('골든: en_${tabName}_$name', (tester) async {
        await pumpGame(tester, loadFixture('stage37_midgame'), tab: tab, size: size, dpr: dpr);
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_${tabName}_$name.png'));
      });
    }
  }
}

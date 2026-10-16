import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart';

import 'ui_harness.dart';

// 선원 개성 v2 표시 (기획 platform-crew-identity-v2 6절): 아이콘 4개 + 한 줄 특색, 40명 모두 ko/en.

void main() {
  test('40명 모두 특색 값과 한 줄 문구(ko/en)가 있다', () async {
    final ko = await AppLocalizations.delegate.load(const Locale('ko'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final ids = GameTables.load().crews.crews.map((c) => c.id).toList();
    expect(ids, hasLength(40));
    final lines = <String>{};
    for (final id in ids) {
      expect(crewIdentities[id], isNotNull, reason: id);
      expect(crewTraitLine(ko, id), isNotEmpty);
      expect(crewTraitLine(en, id), isNotEmpty);
      lines.add(crewTraitLine(ko, id));
    }
    expect(lines, hasLength(40), reason: '한 줄은 선원마다 다르다');
    // 기획 2절: 범위 17명 (S5 확인 2026-10-16, corey는 단일).
    expect(crewIdentities.values.where((v) => v.area), hasLength(17));
  });

  testWidgets('선원 카드에 아이콘 줄, 상세에 특색 판(한 줄 + 조준·연사·범위·명중)', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: crewTab);
    expect(find.byKey(const Key('crew.identity.octo')), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('crew.card.octo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('crew.card.octo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crew.identity.panel.octo')), findsOneWidget);
    expect(find.text('Ink bomb into the crowd'), findsOneWidget);
    expect(find.text('Crowd'), findsOneWidget);
    expect(find.text('Every 1.4s'), findsOneWidget);
    expect(find.text('Leads shots'), findsOneWidget);
  });

  test('연사 막대: 0.3초 = 5칸 · 3초 = 1칸', () {
    expect(rateBars(0.3), 5);
    expect(rateBars(1), 3);
    expect(rateBars(3), 1);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);

    testWidgets('선원 탭 360 ko (아이콘 줄 넘침 없음)', (tester) async {
      await pumpGame(
        tester,
        loadFixture('stage37_midgame'),
        tab: crewTab,
        size: const Size(360, 640),
        dpr: 3,
        locale: const Locale('ko'),
      );
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_crew_identity_360.png'));
    });
  });
}

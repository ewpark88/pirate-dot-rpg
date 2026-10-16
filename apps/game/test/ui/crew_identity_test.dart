import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

import 'ui_harness.dart';

// 선원 개성 v2 표시 (기획 platform-crew-identity-v2 6절): 아이콘 4개 + 한 줄 특색, 40명 모두 ko/en.

void main() {
  test('40명 모두 특색 값과 한 줄 문구(ko/en)가 있다', () async {
    final ko = await AppLocalizations.delegate.load(const Locale('ko'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final t = GameTables.load();
    final ids = t.crews.crews.map((c) => c.id).toList();
    expect(ids, hasLength(40));
    final lines = <String>{};
    for (final id in ids) {
      expect(crewIdentity(t, id), isNotNull, reason: id);
      expect(crewTraitLine(ko, id), isNotEmpty);
      expect(crewTraitLine(en, id), isNotEmpty);
      lines.add(crewTraitLine(ko, id));
    }
    expect(lines, hasLength(40), reason: '한 줄은 선원마다 다르다');
    // 기획 2절: 범위 17명 (S5 확인 2026-10-16, corey는 단일).
    expect(ids.where((id) => crewIdentity(t, id)!.area), hasLength(17));
    // 표에서 읽은 값 몇 개 (기획 2절과 같다).
    // 연사 간격은 표(crews.json aim.intervalSec — S2 공속 조정에도 따라감).
    final octoSec = t.crews.byId('octo').aim!.number('intervalSec');
    final octoReach = crewAttack(t, 'octo', 0).raw.numberOr('reach', 0);
    expect(
      crewIdentity(t, 'octo'),
      (aim: AimKind.cluster, interval: octoSec, area: true, hit: HitKind.lead, range: rangeLevel(octoReach)),
    );
    // 사거리 단계 기준 (S2): ≤ 90 짧음 · ≤ 140 보통 · 그 위 김.
    expect([rangeLevel(90), rangeLevel(91), rangeLevel(140), rangeLevel(141)], [0, 1, 1, 2]);
    expect(crewIdentity(t, 'crabs')!.hit, HitKind.free);
    expect(crewIdentity(t, 'sword')!.hit, HitKind.instant);
    expect(crewIdentity(t, 'turtle')!.aim, AimKind.ring);
    expect(crewIdentity(t, 'gull')!.aim, AimKind.air);
    expect(crewIdentity(t, 'corey')!.area, isFalse);
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
    final sec = shortDecimal(GameTables.load().crews.byId('octo').aim!.number('intervalSec'));
    expect(find.text('Every ${sec}s'), findsOneWidget);
    expect(find.text('Leads shots'), findsOneWidget);
  });

  test('연사 막대: 0.3초 = 5칸 · 3초 = 1칸', () {
    expect(rateBars(0.3), 5);
    expect(rateBars(1), 3);
    expect(rateBars(3), 1);
  });

  testWidgets('신화 단일형 선원 상세: 맞은 자리 작은 폭발(aim.mythic splashRadius) · 연사는 등급 템포(crewAttack)', (tester) async {
    final t = GameTables.load();
    final single = t.crews.crews.firstWhere(
      (c) => crewAttack(t, c.id, 4).raw.numberOr('splashRadius', 0) > 0,
    );
    await pumpGame(tester, loadFixture('all_crews_mythic'), tab: crewTab, fullSheet: true);
    await tester.ensureVisible(find.byKey(Key('crew.card.${single.id}')));
    await tester.pump();
    await tester.tap(find.byKey(Key('crew.card.${single.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crew.identity.splash')), findsOneWidget);
    final sec = shortDecimal(crewAttack(t, single.id, 4).intervalSec);
    expect(find.text('Every ${sec}s'), findsOneWidget);
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

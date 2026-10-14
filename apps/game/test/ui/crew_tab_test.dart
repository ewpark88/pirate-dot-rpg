import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/tabs/crew_tab.dart';

import 'ui_harness.dart';

/// stage37_midgame에서 옥토(Lv15, 일반 상한)의 카드를 채우고 골드를 넉넉히 준 상태.
GameState _octoReady() {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    wallet: s.wallet.copyWith(gold: BigNum.parse('1e30')),
    crews: {...s.crews, 'octo': s.crews['octo']!.copyWith(cards: 99)},
  );
}

Future<void> _show(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
}

void main() {
  testWidgets('기준 7: 선원 40명, 보유 수 = 도감, 출전 표시', (tester) async {
    final state = loadFixture('stage37_midgame');
    await pumpGame(tester, state, tab: crewTab);
    final cards = tester.widgetList<CrewCard>(find.byType(CrewCard, skipOffstage: false));
    expect(cards, hasLength(40));
    expect(cards.where((c) => c.owned).map((c) => c.crewId).toSet(), state.crews.keys.toSet());
    expect(find.text('Collection 4/40'), findsOneWidget);
    expect(find.text('Deployed', skipOffstage: false), findsNWidgets(state.battle!.fleet.length));
  });

  testWidgets('기준 7: 일괄 합치기 → MergeAllCards', (tester) async {
    final log = await pumpGame(tester, loadFixture('stage37_midgame'), tab: crewTab);
    await tester.tap(find.byKey(const Key('crew.mergeAll')));
    expect(log.sent, [isA<MergeAllCards>()]);
  });

  testWidgets('기준 8: 승급 문 앞이지만 카드가 모자라면 버튼 비활성, 빨간 점 없음', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: crewTab);
    await _show(tester, 'crew.promote.octo');
    expect(tester.widget<FilledButton>(find.byKey(const Key('crew.promote.octo'))).onPressed, isNull);
    expect(find.byKey(const Key('crew.dot.octo')), findsNothing);
    // 승급 문 앞이 아닌 선원(망타 Lv46)은 버튼 자체가 없다
    expect(find.byKey(const Key('crew.promote.manta'), skipOffstage: false), findsNothing);
  });

  testWidgets('기준 8: 조건을 채우면 빨간 점 + PromoteCrew', (tester) async {
    final log = await pumpGame(tester, _octoReady(), tab: crewTab);
    await _show(tester, 'crew.promote.octo');
    expect(find.byKey(const Key('crew.dot.octo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('crew.promote.octo')));
    expect(log.sent.map((c) => c.toJson()), [
      {'type': 'promoteCrew', 'crewId': 'octo'},
    ]);
  });

  testWidgets('기준 8: 모두 신화면 승급 버튼이 없다', (tester) async {
    await pumpGame(tester, loadFixture('all_crews_mythic'), tab: crewTab);
    expect(
      find.byWidgetPredicate((w) => '${w.key}'.contains('crew.promote.'), skipOffstage: false),
      findsNothing,
    );
  });
}

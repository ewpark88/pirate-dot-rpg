import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

import 'ui_harness.dart';

PixelButton _button(WidgetTester tester, String key) => tester.widget<PixelButton>(find.byKey(Key(key)));

void main() {
  final tables = GameTables.load();

  testWidgets('기준 6: 젬 140이면 1회만 활성, 누르면 Summon(1)', (tester) async {
    final log = await pumpGame(tester, loadFixture('stage37_midgame'), tab: summonTab);
    expect(find.text('${summonCost(tables.meta, 1)}'), findsOneWidget);
    expect(find.text('${summonCost(tables.meta, 10)}'), findsOneWidget);
    expect(_button(tester, 'summon.ten').onPressed, isNull);

    await tester.tap(find.byKey(const Key('summon.one')));
    expect(log.sent.map((c) => c.toJson()), [
      {'type': 'summon', 'count': 1},
    ]);
  });

  testWidgets('기준 6: 젬이 충분하면 10회 → Summon(10)', (tester) async {
    final log = await pumpGame(tester, loadFixture('all_crews_mythic'), tab: summonTab);
    await tester.tap(find.byKey(const Key('summon.ten')));
    expect(log.sent.map((c) => c.toJson()), [
      {'type': 'summon', 'count': 10},
    ]);
  });

  testWidgets('기준 6: 천장 진행과 확률표(테이블 값 그대로)', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: summonTab);
    expect(find.text('17/${tables.rarities.pityCount}'), findsOneWidget);
    expect(find.text('Hero+ guaranteed within ${tables.rarities.pityCount}'), findsOneWidget);

    final summonable = tables.rarities.rarities.where((r) => r.summonRate > 0).toList();
    expect(summonable, hasLength(4));
    for (final r in summonable) {
      final rate = find.byKey(Key('summon.rate.${r.id}'));
      expect(rate, findsOneWidget);
      expect(
        find.descendant(of: rate, matching: find.text('${shortDecimal(r.summonRate * 100)}%')),
        findsOneWidget,
        reason: r.id,
      );
    }
    expect(find.byKey(const Key('summon.rate.mythic')), findsNothing); // 신화는 소환에 없다
  });

  testWidgets('첫 10연 무료면 10회 버튼에 Free, 젬이 없어도 활성', (tester) async {
    final base = loadFixture('stage37_midgame');
    final state = base.copyWith(summonsTotal: 0, wallet: base.wallet.copyWith(gems: 0));
    expect(isFreeFirstTen(state, tables, 10), isTrue, reason: '테이블 meta.tutorial.firstTenSummonFree');
    final log = await pumpGame(tester, state, tab: summonTab);
    expect(find.byKey(const Key('summon.free')), findsOneWidget);
    expect(_button(tester, 'summon.one').onPressed, isNull); // 1회는 무료가 아니고 젬 0
    await tester.tap(find.byKey(const Key('summon.ten')));
    expect(log.sent.map((c) => c.toJson()), [
      {'type': 'summon', 'count': 10},
    ]);
  });
}

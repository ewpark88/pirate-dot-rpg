import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

import 'ui_harness.dart';

FilledButton _button(WidgetTester tester, String part) =>
    tester.widget<FilledButton>(find.byKey(Key('ship.upgrade.$part')));

void main() {
  final tables = GameTables.load();

  testWidgets('기준 4: 부위 5줄, 레벨·효과·비용, 누르면 UpgradePart', (tester) async {
    final log = await pumpGame(tester, loadFixture('stage37_midgame'), tab: shipTab);
    for (final name in ['Cannon', 'Hull', 'Sail', "Crow's Nest", 'Cargo Hold']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('Lv 52'), findsOneWidget);
    expect(find.text('Lv 18/30'), findsOneWidget); // 돛은 최대 레벨이 있다
    expect(find.text(partEffect(tables.shipParts.byId('cannon'), 52).format()), findsOneWidget);
    expect(find.text('17%'), findsOneWidget); // 망루 Lv12: 5% + 1% × 12
    expect(find.text('×1.9'), findsNWidgets(2)); // 돛 Lv18, 화물칸 Lv9
    expect(find.text(partCost(tables.shipParts.byId('cannon'), 52).format()), findsOneWidget);

    await tester.tap(find.byKey(const Key('ship.upgrade.cannon')));
    expect(log.sent.map((c) => c.toJson()), [
      {'type': 'upgradePart', 'part': 'cannon', 'times': 1},
    ]);
  });

  testWidgets('기준 5: 최대 레벨이면 비활성 + MAX', (tester) async {
    await pumpGame(tester, loadFixture('all_crews_mythic'), tab: shipTab);
    expect(_button(tester, 'sail').onPressed, isNull);
    expect(_button(tester, 'crowsnest').onPressed, isNull);
    expect(find.text('MAX'), findsNWidgets(2));
    // 최대 레벨이 없는 부위는 MAX 대신 비용을 보인다 (Lv400 비용이 골드보다 커서 비활성).
    expect(find.text(partCost(tables.shipParts.byId('cannon'), 400).format()), findsOneWidget);
  });

  testWidgets('기준 5: 골드가 모자라면 비활성', (tester) async {
    await pumpGame(tester, loadFixture('new_player'), tab: shipTab);
    for (final p in tables.shipParts.parts) {
      expect(_button(tester, p.id).onPressed, isNull, reason: p.id);
    }
  });
}

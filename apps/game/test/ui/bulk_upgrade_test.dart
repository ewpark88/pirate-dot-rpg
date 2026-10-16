import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/tabs/upgrade_multiplier.dart';

import 'ui_harness.dart';

// 일괄 강화 배수 알약 (S1 지시): ×1·×5·×10·×20·×50·MAX → UpgradePart(times) / UpgradePart.max.

void main() {
  final tables = GameTables.load();
  final cannon = tables.shipParts.byId('cannon');

  test('bulkUpgrade: 골드가 넉넉하면 배수만큼, 모자라면 살 수 있는 만큼, MAX는 살 수 있는 전부', () {
    final rich = BigNum.from(1e30);
    expect(bulkUpgrade(cannon, 10, rich, 5).$1, 5);
    expect(bulkUpgrade(cannon, 10, rich, 5).$2, partCostSum(cannon, 10, 5));
    final three = partCostSum(cannon, 10, 3);
    expect(bulkUpgrade(cannon, 10, three, 10).$1, 3);
    expect(bulkUpgrade(cannon, 10, three, 0).$1, 3);
    // 하나도 못 사면 레벨 0, 비용은 목표만큼 (MAX는 1회).
    expect(bulkUpgrade(cannon, 10, BigNum.zero, 10), (0, partCostSum(cannon, 10, 10)));
    expect(bulkUpgrade(cannon, 10, BigNum.zero, 0), (0, partCost(cannon, 10)));
  });

  testWidgets('알약을 고르면 버튼이 그 배수로 강화하고 오를 레벨 수를 보인다', (tester) async {
    // 골드는 대포 ×5를 살 만큼(표에서 계산 — 경제가 비용을 바꿔도 깨지지 않게).
    final st = loadFixture('stage37_midgame');
    final gold = partCostSum(cannon, st.ship.level('cannon'), 5).times(2);
    final log = await pumpGame(
      tester,
      st.copyWith(wallet: st.wallet.copyWith(gold: gold)),
      tab: shipTab,
    );
    expect(find.byKey(const Key('ship.upgrade.levels.cannon')), findsNothing);
    await tester.tap(find.byKey(const Key('ship.mult.5')));
    await tester.pump();
    expect(find.byKey(const Key('ship.upgrade.levels.cannon')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ship.upgrade.cannon')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ship.mult.max')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ship.upgrade.cannon')));
    await tester.pump();
    expect(
      [for (final c in log.sent) c.toJson()],
      [
        const UpgradePart('cannon', times: 5).toJson(),
        const UpgradePart.max('cannon').toJson(),
      ],
    );
  });

  testWidgets('골든: 배 탭 ×10 ko', (tester) async {
    await loadGoldenFonts();
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: shipTab, locale: const Locale('ko'));
    await precacheImages(tester);
    await tester.tap(find.byKey(const Key('ship.mult.10')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_ship_bulk.png'));
  });
}

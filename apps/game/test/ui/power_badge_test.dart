import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 전투력 표시 (S1 지시): fleetPower 숫자, 오르면 굴러 오르고 초록 '+N'.

void main() {
  testWidgets('전투력 = 경제 fleetPower, 대포를 올리면 굴러 올라가고 +N이 잠깐 뜬다', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, openTab: false);
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final tables = container.read(tablesProvider);
    final before = fleetPower(s, tables).power;
    expect(tester.widget<Text>(find.byKey(const Key('hud.power.value'))).data, before.format());
    expect(find.byKey(const Key('hud.power.gain')), findsNothing);

    final up = s.copyWith(ship: s.ship.withLevel('cannon', s.ship.level('cannon') + 20));
    final after = fleetPower(up, tables).power;
    container.read(gameStateProvider.notifier).replace(up);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('+${(after - before).format()}'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<Text>(find.byKey(const Key('hud.power.value'))).data, after.format());
    expect(find.byKey(const Key('hud.power.gain')), findsNothing);
  });

  testWidgets('내려가면 +N 없이 굴러 내려가기만', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, openTab: false);
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final down = s.copyWith(ship: s.ship.withLevel('cannon', 1));
    container.read(gameStateProvider.notifier).replace(down);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('hud.power.gain')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.widget<Text>(find.byKey(const Key('hud.power.value'))).data,
      fleetPower(down, container.read(tablesProvider)).power.format(),
    );
  });
}

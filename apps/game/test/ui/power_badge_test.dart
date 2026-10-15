import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 전투력 표시: fleetPower 숫자가 바로 바뀐다(사용자 지시 — '+N'·움직임 없음).

void main() {
  testWidgets('전투력 = 경제 fleetPower, 대포를 올리면 숫자만 바로 바뀐다', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, openTab: false);
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final tables = container.read(tablesProvider);
    expect(tester.widget<Text>(find.byKey(const Key('hud.power.value'))).data, fleetPower(s, tables).power.format());
    final up = s.copyWith(ship: s.ship.withLevel('cannon', s.ship.level('cannon') + 20));
    container.read(gameStateProvider.notifier).replace(up);
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('hud.power.value'))).data, fleetPower(up, tables).power.format());
  });
}

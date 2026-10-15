import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 스테이지 진행 게이지 (S1 지시): 파 칸 + 보스 해골, 해역 진행, 보스 직전 빨간 맥박, 보스 중 시간 막대.

GameState _at({int wave = 1, bool farming = false, bool boss = false, int ticks = 0}) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    progress: s.progress.copyWith(wave: wave, farming: farming),
    battle: s.battle!.copyWith(bossActive: boss, bossTicksLeft: ticks),
  );
}

Color _segColor(WidgetTester tester, int i) {
  final box = tester.widget<AnimatedContainer>(
    find.descendant(of: find.byKey(Key('hud.gauge.wave.$i')), matching: find.byType(AnimatedContainer)),
  );
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('파 1개 깸: 스테이지 37-2, 첫 칸 채움, 둘째 칸 지금, 해역 진행 37/50', (tester) async {
    await pumpGame(tester, _at(), openTab: false);
    expect(find.text('37-2'), findsOneWidget);
    expect(_segColor(tester, 0), isNot(_segColor(tester, 2)));
    final region = tester.widget<LinearProgressIndicator>(find.byKey(const Key('hud.gauge.region')));
    expect(region.value, closeTo(37 / 50, 1e-9));
    expect(find.byKey(const Key('hud.gauge.skull.hot')), findsNothing);
  });

  testWidgets('파를 다 깨면 해골이 빨갛게 뛰고(끝이 있음), 보스가 나오면 시간 막대·남은 초', (tester) async {
    await pumpGame(tester, _at(), openTab: false);
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    container.read(gameStateProvider.notifier).replace(_at(wave: 3));
    await tester.pump();
    expect(find.byKey(const Key('hud.gauge.skull.hot')), findsOneWidget);
    await tester.pumpAndSettle(); // 맥박은 끝난다.

    container.read(gameStateProvider.notifier).replace(_at(wave: 3, boss: true, ticks: 600));
    await tester.pump();
    expect(find.byKey(const Key('hud.gauge.timer')), findsOneWidget);
    expect(find.text('30s'), findsOneWidget);
    container.read(gameStateProvider.notifier).replace(_at(wave: 3, boss: true, ticks: 150));
    await tester.pump();
    expect(find.text('8s'), findsOneWidget);
    final bar = tester.widget<FractionallySizedBox>(
      find.descendant(of: find.byKey(const Key('hud.gauge.timer')), matching: find.byType(FractionallySizedBox)),
    );
    expect(bar.widthFactor, closeTo(0.25, 1e-9));
  });

  testWidgets('파밍 중: 해골은 뛰지 않는다', (tester) async {
    await pumpGame(tester, _at(wave: 3, farming: true), openTab: false);
    expect(find.byKey(const Key('hud.gauge.skull.hot')), findsNothing);
    expect(find.byKey(const Key('hud.gauge.skull')), findsOneWidget);
  });

  testWidgets('골든: 보스 중 게이지 ko', (tester) async {
    await loadGoldenFonts();
    await pumpGame(tester, _at(wave: 3, boss: true, ticks: 300), locale: const Locale('ko'), openTab: false);
    await precacheImages(tester);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_stage_gauge_boss.png'));
  });
}

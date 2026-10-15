import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/analytics_provider.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

class _FakeAnalytics implements AnalyticsPort {
  final seen = <(String, int)>[];

  @override
  void log(String event, [Map<String, Object> params = const {}]) {}

  @override
  void setLastSeen({required String screen, required int stage}) => seen.add((screen, stage));
}

void main() {
  testWidgets('이탈 분석: 시작·탭 전환·스테이지 변경 때 마지막 화면·스테이지 (설계서 4.9)', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final analytics = _FakeAnalytics();
    final state = loadFixture('stage37_midgame').copyWith(clearTutorial: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialGameStateProvider.overrideWithValue(state),
          battleViewBuilderProvider.overrideWithValue((_) => const SizedBox()),
          clockProvider.overrideWithValue(FixedClock(state.savedAt)),
          analyticsPortProvider.overrideWithValue(analytics),
        ],
        child: const PirateDotApp(locale: Locale('en')),
      ),
    );
    await tester.pump();
    expect(analytics.seen, [('voyage', 37)]);

    await tester.tap(find.byKey(const Key('tab.$shipTab')));
    await tester.pump();
    expect(analytics.seen.last, ('ship', 37));

    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    container.read(gameStateProvider.notifier).replace(state.copyWith(progress: state.progress.copyWith(stage: 38)));
    await tester.pump();
    expect(analytics.seen.last, ('ship', 38));
  });
}

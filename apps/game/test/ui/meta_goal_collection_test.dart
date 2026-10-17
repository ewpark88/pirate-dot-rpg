import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/meta/trial_gate.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

/// 경제 함수(B1·B9)가 오기 전이라 provider를 가짜로 덮어 화면만 시험한다.
GameState _at25() {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(progress: s.progress.copyWith(stage: 25));
}

Future<void> _pump(WidgetTester tester, {NextGoal? goal, CollectionBonus? bonus, int tab = 0}) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // 스테이지 37은 '환생까지 n'이 목표 자리를 쓰므로(해금 10스테이지 전) 25로.
  final state = _at25();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trialsEnabledProvider.overrideWithValue(false),
        initialGameStateProvider.overrideWithValue(state),
        battleViewBuilderProvider.overrideWithValue((_) => const SizedBox()),
        clockProvider.overrideWithValue(FixedClock(state.savedAt)),
        if (goal != null) nextGoalProvider.overrideWithValue((_) => goal),
        if (bonus != null) collectionBonusProvider.overrideWithValue((_) => bonus),
      ],
      child: const PirateDotApp(locale: Locale('en')),
    ),
  );
  await tester.pump();
  {
    await tester.tap(find.byKey(Key('tab.$tab')));
    // 시트가 올라오는 시간 (첫 프레임에 애니메이션이 시작된다).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }
}

void main() {
  testWidgets('기준 1: 목표 막대 — 배 승급까지 스테이지 4', (tester) async {
    await _pump(
      tester,
      goal: const NextGoal(kind: GoalKind.shipTier, id: 'sloop', remaining: 4, progress: 0.6),
    );
    expect(find.byKey(const Key('goal')), findsOneWidget);
    expect(find.textContaining('in 4 stages'), findsOneWidget);
    // 목표는 진행 게이지 안 얇은 한 줄(S1 지시) — 막대는 작은 LinearProgressIndicator.
    final bar = tester.widget<LinearProgressIndicator>(
      find.descendant(of: find.byKey(const Key('goal')), matching: find.byType(LinearProgressIndicator)),
    );
    expect(bar.value, 0.6);
  });

  testWidgets('기준 1: 부위 도약 문구', (tester) async {
    await _pump(
      tester,
      goal: const NextGoal(kind: GoalKind.partMilestone, id: 'cannon', remaining: 3, progress: 0.1),
    );
    expect(find.text('Cannon boost in 3 levels'), findsOneWidget);
  });

  testWidgets('기본값은 경제 nextGoal — 샘플에 목표 막대가 보인다', (tester) async {
    await pumpGame(tester, _at25());
    expect(find.byKey(const Key('goal')), findsOneWidget);
  });

  testWidgets('기준 7: 도감 보너스 줄 — 공격력 +0%, 다음 보너스까지 1명', (tester) async {
    await _pump(tester, bonus: const CollectionBonus(owned: 4, total: 40, attackBonus: 0, nextAt: 5), tab: crewTab);
    expect(find.text('Attack +0%'), findsOneWidget);
    expect(find.text('Next bonus in 1'), findsOneWidget);
  });

  testWidgets('기본값은 경제 collectionBonus — 도감 4명이면 +0%, 다음까지 1명', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: crewTab);
    expect(find.text('Attack +0%'), findsOneWidget);
    expect(find.text('Next bonus in 1'), findsOneWidget);
  });
}

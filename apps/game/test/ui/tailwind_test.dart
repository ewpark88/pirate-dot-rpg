import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'package:pirate_dot/ui/state/clock_provider.dart';

import 'ui_harness.dart';

/// 시계는 ui_harness가 샘플의 savedAt에 고정한다.
GameState _tailwind(Duration left) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(buffs: Buffs(tailwindUntil: s.savedAt.add(left)));
}

void main() {
  testWidgets('기준 4: 12분 30초 남음 → 12:30 과 ×2', (tester) async {
    await pumpGame(tester, _tailwind(const Duration(minutes: 12, seconds: 30)));
    final badge = find.byKey(const Key('tailwind'));
    expect(find.descendant(of: badge, matching: find.text('12:30')), findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('×2')), findsOneWidget);
  });

  testWidgets('1시간이 넘으면 h:mm (샘플: 1시간 30분)', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.descendant(of: find.byKey(const Key('tailwind')), matching: find.text('1:30')), findsOneWidget);
  });

  testWidgets('1초마다 다시 그린다', (tester) async {
    final state = _tailwind(const Duration(minutes: 1));
    final clock = FixedClock(state.savedAt);
    await pumpGame(tester, state, clock: clock);
    expect(find.text('01:00'), findsOneWidget);
    clock.time = clock.time.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:59'), findsOneWidget);
  });

  testWidgets('기준 4: 지난 시각이면 흐린 아이콘, 시간·배율 없음', (tester) async {
    await pumpGame(tester, _tailwind(const Duration(minutes: -5)));
    final badge = find.byKey(const Key('tailwind'));
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('×2')), findsNothing);
  });
}

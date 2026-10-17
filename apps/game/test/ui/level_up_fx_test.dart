import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/crew/level_up_fx.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 선원 레벨업 반짝이 (S1 2026-10-17): 레벨이 오르면 카드 위 'LEVEL UP!' + 별 + 튕김, 일괄이면 0.08초 차례.

GameState _up(GameState s, Iterable<String> ids) => s.copyWith(
  crews: {
    for (final e in s.crews.entries) e.key: ids.contains(e.key) ? e.value.copyWith(level: e.value.level + 1) : e.value,
  },
);

void main() {
  testWidgets('한 명 레벨업 → LEVEL UP! 한 번, 0.9초 뒤 사라짐 · 레벨 그대로면 없음', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, tab: crewTab);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    c.read(gameStateProvider.notifier).replace(s.copyWith());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('crew.levelUpFx')), findsNothing);
    c.read(gameStateProvider.notifier).replace(_up(s, [s.crews.keys.first]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('crew.levelUpFx')), findsOneWidget);
    // 연출은 다음 프레임에 시작한다(0.2초 지점) — 그로부터 0.9초 뒤.
    await tester.pump(levelUpFxFor + const Duration(milliseconds: 250));
    expect(find.byKey(const Key('crew.levelUpFx')), findsNothing);
  });

  testWidgets('일괄 합치기(여러 명 한 번에) → 카드마다 0.08초 간격으로 차례', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, tab: crewTab);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final ids = s.crews.keys.take(3).toList();
    c.read(gameStateProvider.notifier).replace(_up(s, ids));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    final first = find.byKey(const Key('crew.levelUpFx')).evaluate().length;
    await tester.pump(levelUpStagger * 3);
    final later = find.byKey(const Key('crew.levelUpFx')).evaluate().length;
    expect(first, lessThan(later), reason: '처음엔 일부만, 0.24초 뒤엔 더 많이');
    await tester.pump(levelUpFxFor + levelUpStagger * 3);
  });
}

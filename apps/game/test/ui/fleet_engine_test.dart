import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/engine_host.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

/// 사용자 버그(2026-10-15): "출전 칸 선원을 바꿔도 무기 그림·공격력이 안 바뀐다". 실제 엔진(EngineHost) + 앱으로 재현.
/// 칸을 바꾸는 UI 경로 → state.fleet → 다음 틱들의 AttackFired.crewId 까지 확인한다.
Future<(EngineHost, List<RecordedTick>)> _pumpReal(WidgetTester tester, GameState initial) async {
  tester.view
    ..physicalSize = s24Size * s24Dpr
    ..devicePixelRatio = s24Dpr;
  addTearDown(tester.view.reset);
  final tables = GameTables.load();
  final clock = FixedClock(initial.savedAt);
  final host = EngineHost(tables: tables, initial: initial, clock: clock);
  final ticks = <RecordedTick>[];
  final sub = host.ticks.listen(ticks.add);
  addTearDown(sub.cancel);
  final container = ProviderContainer(
    overrides: [
      tablesProvider.overrideWithValue(tables),
      initialGameStateProvider.overrideWithValue(host.state),
      commandSinkProvider.overrideWithValue(host),
      battleFeedProvider.overrideWithValue(host.ticks),
      clockProvider.overrideWithValue(clock),
      battleViewBuilderProvider.overrideWithValue((_) => const ColoredBox(color: Colors.blueGrey)),
    ],
  );
  addTearDown(container.dispose);
  host.onState = container.read(gameStateProvider.notifier).replace;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const PirateDotApp(locale: Locale('en')),
    ),
  );
  await tester.pump();
  return (host, ticks);
}

/// 엔진을 [n]틱 돌리고 화면을 다시 그린다.
Future<void> _run(WidgetTester tester, EngineHost host, int n) async {
  for (var i = 0; i < n; i++) {
    host.step();
  }
  await tester.pump();
}

Set<String> _attackers(List<RecordedTick> ticks) => {
  for (final t in ticks)
    for (final e in t.events)
      if (e is AttackFired) e.crewId,
};

void main() {
  setUpAll(() async => AppLocalizations.delegate.load(const Locale('en')));

  testWidgets('선원 상세 → 출전(가득) → 바꿀 선원 → 엔진 fleet·공격 선원이 바뀐다', (tester) async {
    final base = loadFixture('stage37_midgame').copyWith(clearTutorial: true);
    // 출전 안 한 보유 선원 하나를 더한다(스타리, 옥토와 같은 레벨).
    final ids = [for (final f in base.battle!.fleet) f.crewId];
    final initial = base.copyWith(
      crews: {...base.crews, 'starry': base.crews['octo']!},
      fleet: ids,
      fleetInit: true,
    );
    final (host, ticks) = await _pumpReal(tester, initial);
    await _run(tester, host, 3);
    final before = host.state.fleet;
    expect(before, isNot(contains('starry')));
    final out = before.firstWhere((id) => id != null)!;

    await tester.tap(find.byKey(const Key('tab.$crewTab')));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(const Key('crew.card.starry')));
    await tester.tap(find.byKey(const Key('crew.card.starry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crew.detail.deploy.starry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('fleet.swap.$out')));
    await tester.pumpAndSettle();

    await _run(tester, host, 2);
    expect(host.state.fleet, contains('starry'), reason: 'fleet ${host.state.fleet}');
    expect(host.state.fleet, isNot(contains(out)));
    ticks.clear();
    await _run(tester, host, 400);
    expect(_attackers(ticks), contains('starry'));
    expect(_attackers(ticks), isNot(contains(out)));
  });

  testWidgets('열린 빈 칸 → 후보 고르기 → 엔진 fleet에 들어가고 공격한다', (tester) async {
    final base = loadFixture('stage37_midgame').copyWith(clearTutorial: true);
    final ids = [for (final f in base.battle!.fleet) f.crewId];
    final initial = base.copyWith(fleet: [...ids.take(ids.length - 1), null], fleetInit: true);
    final removed = ids.last;
    final (host, ticks) = await _pumpReal(tester, initial);
    await _run(tester, host, 3);
    expect(host.state.fleet, isNot(contains(removed)));

    await tester.tap(find.byKey(Key('fleet.slot.${ids.length - 1}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('fleet.pick.$removed')));
    await tester.pumpAndSettle();

    await _run(tester, host, 2);
    expect(host.state.fleet, contains(removed), reason: 'fleet ${host.state.fleet}');
    ticks.clear();
    await _run(tester, host, 400);
    expect(_attackers(ticks), contains(removed));
  });

  for (final init in [true, false]) {
    testWidgets('출전 칸 → 선원 상세 → 바꾸기 → 쉬는 선원 (fleetInit=$init) → 엔진 fleet·공격이 바뀐다', (tester) async {
      final base = loadFixture('stage37_midgame').copyWith(clearTutorial: true);
      final ids = [for (final f in base.battle!.fleet) f.crewId];
      // 쉬는 선원: 스타리 Lv1 (자동 편성에 안 뽑히게 약하게).
      final rookie = base.crews['octo']!.copyWith(level: 1);
      final initial = base.copyWith(
        crews: {...base.crews, 'starry': rookie},
        fleet: init ? ids : const [],
        fleetInit: init,
      );
      final (host, ticks) = await _pumpReal(tester, initial);
      await _run(tester, host, 3);
      final first = host.state.fleet.first!;
      expect(host.state.fleet, isNot(contains('starry')));

      await tester.tap(find.byKey(const Key('fleet.crew.0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('crew.detail.replace.$first')));
      await tester.pumpAndSettle();
      // 쉬는 선원이 맨 위.
      final rows = find.byWidgetPredicate((w) => '${w.key}'.contains('fleet.pick.'));
      expect('${tester.widget(rows.first).key}', contains('starry'));
      await tester.tap(find.byKey(const Key('fleet.pick.starry')));
      await tester.pumpAndSettle();

      await _run(tester, host, 2);
      expect(host.state.fleet.first, 'starry', reason: 'fleet ${host.state.fleet}');
      ticks.clear();
      await _run(tester, host, 400);
      expect(_attackers(ticks), contains('starry'));
      expect(_attackers(ticks), isNot(contains(first)));
    });
  }
}

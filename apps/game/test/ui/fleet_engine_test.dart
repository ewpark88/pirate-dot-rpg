import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/engine_host.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/crew/crew_preview.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/story/story_data.dart';

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
  final host = EngineHost(tables: tables, initial: withGuidesSeen(initial), clock: clock);
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
      // 보스 대화창(시나리오)은 이 시험의 관심 밖 — 실제 엔진이 보스를 내도 뜨지 않게.
      storyEnabledProvider.overrideWithValue(false),
      crewPreviewPlayProvider.overrideWithValue(false),
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // 정렬·필터 줄이 생겨 카드가 아래로 — 화면 위쪽으로 끌어와 누른다.
    await Scrollable.ensureVisible(tester.element(find.byKey(const Key('crew.card.starry'))), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crew.card.starry')));
    await tester.pumpAndSettle();
    // 상세 창이 길어(개편·피해 줄) 출전 버튼은 창 안에서 굴려 본다.
    await tester.ensureVisible(find.byKey(const Key('crew.detail.deploy.starry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crew.detail.deploy.starry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('fleet.swap.$out')));
    await tester.pumpAndSettle();
    // 비교 창(#34)에서 교체.
    expect(find.byKey(const Key('swap.compare')), findsOneWidget);
    await tester.tap(find.byKey(const Key('swap.confirm')));
    await tester.pumpAndSettle();

    await _run(tester, host, 2);
    expect(host.state.fleet, contains('starry'), reason: 'fleet ${host.state.fleet}');
    expect(host.state.fleet, isNot(contains(out)));
    ticks.clear();
    await _run(tester, host, 400);
    expect(_attackers(ticks), contains('starry'));
    expect(_attackers(ticks), isNot(contains(out)));
    await tester.pump(const Duration(seconds: 5)); // 실제 엔진의 도감 첫 처치 토스트(4초)가 닫히게
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
    await tester.pump(const Duration(seconds: 5)); // 실제 엔진의 도감 첫 처치 토스트(4초)가 닫히게
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
      await tester.ensureVisible(find.byKey(Key('crew.detail.replace.$first')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('crew.detail.replace.$first')));
      await tester.pumpAndSettle();
      // 쉬는 선원이 맨 위.
      final rows = find.byWidgetPredicate((w) => '${w.key}'.contains('fleet.pick.'));
      expect('${tester.widget(rows.first).key}', contains('starry'));
      await tester.tap(find.byKey(const Key('fleet.pick.starry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('swap.confirm'))); // 비교 창(#34)
      await tester.pumpAndSettle();

      await _run(tester, host, 2);
      expect(host.state.fleet.first, 'starry', reason: 'fleet ${host.state.fleet}');
      ticks.clear();
      await _run(tester, host, 400);
      expect(_attackers(ticks), contains('starry'));
      expect(_attackers(ticks), isNot(contains(first)));
      await tester.pump(const Duration(seconds: 5)); // 실제 엔진의 도감 첫 처치 토스트(4초)가 닫히게
    });
  }

  testWidgets('사용자 버그 2026-10-16: 합치기·승급·강화·자동 강화 몇 분 — 출전 선원이 빠지지 않는다 (실제 엔진)', (tester) async {
    final base = loadFixture('stage37_midgame');
    final (host, _) = await _pumpReal(tester, base);
    await _run(tester, host, 3);
    final before = [...host.state.fleet];
    expect(before.whereType<String>(), isNotEmpty);
    host
      ..send(const MergeAllCards())
      ..send(PromoteCrew(before.whereType<String>().first))
      ..send(const UpgradePart('cannon', times: 5))
      ..send(const Summon(count: 10));
    await _run(tester, host, 20);
    await _run(tester, host, 2400); // 약 2분 (자동 강화·보스·카드 드롭 포함)
    expect(host.state.fleet.whereType<String>().toList(), before.whereType<String>().toList());
    await tester.pump(const Duration(seconds: 5)); // 실제 엔진의 도감 첫 처치 토스트(4초)가 닫히게
  });

  testWidgets('내리면 4초 동안 되돌리기', (tester) async {
    final base = loadFixture('stage37_midgame');
    final ids = base.battle!.fleet.map((f) => f.crewId).toList();
    final (host, _) = await _pumpReal(tester, base.copyWith(fleet: [ids.first, ids[1], null, null], fleetInit: true));
    await _run(tester, host, 2);
    await tester.tap(find.byKey(const Key('fleet.crew.1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(Key('crew.detail.undeploy.${ids[1]}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('crew.detail.undeploy.${ids[1]}')));
    await tester.pump();
    await _run(tester, host, 2);
    expect(host.state.fleet.whereType<String>().toList(), [ids.first]);
    await tester.tap(find.byKey(const Key('skin.toast.action')));
    await tester.pump();
    await _run(tester, host, 2);
    expect(host.state.fleet.whereType<String>().toList(), [ids.first, ids[1]]);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('마지막 출전 선원은 내릴 수 없다', (tester) async {
    final base = loadFixture('stage37_midgame');
    final id = base.battle!.fleet.first.crewId;
    final (host, _) = await _pumpReal(tester, base.copyWith(fleet: [id, null, null, null], fleetInit: true));
    await _run(tester, host, 2);
    await tester.tap(find.byKey(const Key('fleet.crew.0')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(Key('crew.detail.undeploy.$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('crew.detail.undeploy.$id')));
    await tester.pump();
    await _run(tester, host, 2);
    expect(host.state.fleet.whereType<String>().toList(), [id]);
    expect(find.text('Keep at least one crew deployed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';

import 'ui_harness.dart';

// 심연의 탑 · 보스 러시 화면 (S5 계약 platform-tower.md · 러시): 항해 탭 카드 2장, 전투 중 띠·후퇴, 결과 창·소탕 토스트.

const _tall = Size(400, 1600);

GameState _state({
  int towerTickets = 2,
  int best = 12,
  int rushTickets = 7,
  int? bestTicks,
  List<int> claimed = const [],
}) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    progress: s.progress.copyWith(bestStage: 80),
    tower: TowerState(tickets: towerTickets, refilledOn: '2026-10-12', best: best, firstCleared: best),
    rush: RushState(week: '2026-10-12', tickets: rushTickets, bestTicks: bestTicks, claimed: claimed),
  );
}

Future<void> _show(WidgetTester tester, String key) => showInSheet(tester, key);

void main() {
  testWidgets('탑 카드: 최고 12층 · 도전권 2/3 · 도전 → StartTower · 소탕 9층(12×0.8) → SweepTower', (tester) async {
    final log = await pumpGame(tester, _state(), size: _tall);
    await _show(tester, 'tower.card');
    expect(find.text('Best: F12'), findsOneWidget);
    expect(find.text('Tickets 2/3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tower.start')));
    await tester.tap(find.text('Sweep F9'));
    await tester.pump();
    expect(log.sent.whereType<StartTower>(), hasLength(1));
    expect(log.sent.whereType<SweepTower>(), hasLength(1));
  });

  testWidgets('탑 열리기 전(상태 없음)엔 카드가 없다', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, size: _tall);
    expect(find.byKey(const Key('tower.card')), findsNothing);
    expect(find.byKey(const Key('rush.card')), findsNothing);
  });

  testWidgets('도전권 0: 도전 버튼 없이 안내 + 광고 자리', (tester) async {
    await pumpGame(tester, _state(towerTickets: 0), size: _tall);
    await _show(tester, 'tower.card');
    expect(find.byKey(const Key('tower.start')), findsNothing);
    expect(find.text('No tickets — more tomorrow'), findsOneWidget);
  });

  testWidgets('러시 카드: 이번 주 보스 5 · 구간 3(받은 구간 표시) · 최고 기록 m:ss · 도전 → StartRush', (tester) async {
    final t = GameTables.load();
    final ticks = (100 * 1000 / t.waves.tickMs).round(); // 1:40
    final log = await pumpGame(
      tester,
      _state(bestTicks: ticks, claimed: [0]),
      size: _tall,
    );
    await _show(tester, 'rush.card');
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(Key('rush.boss.$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('rush.bracket.2')), findsOneWidget);
    expect(find.text('Best 1:40'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rush.start')));
    await tester.pump();
    expect(log.sent.whereType<StartRush>(), hasLength(1));
  });

  testWidgets('탑 전투 중: 띠 "Abyss F12 · wave 2/3" · 보스 도전·피버 숨김 · 후퇴 → RetreatTower', (tester) async {
    final s = _state();
    final farming = s.copyWith(
      progress: s.progress.copyWith(farming: true),
      battle: s.battle!.copyWith(tower: const TowerView(floor: 12, wave: 1, waves: 3)),
    );
    final log = await pumpGame(tester, farming, openTab: false);
    expect(find.text('Abyss F12 · wave 2/3'), findsOneWidget);
    expect(find.byKey(const Key('boss.challenge')), findsNothing);
    expect(find.byKey(const Key('fun.fever.chip')), findsNothing);
    // 후퇴는 띠 안 — 배 체력 막대·선원 줄과 안 겹친다(사용자 2026-10-18).
    final retreat = tester.getRect(find.byKey(const Key('scene.retreat')));
    expect(retreat.overlaps(tester.getRect(find.byKey(const Key('hud.shipHp')))), isFalse);
    expect(retreat.bottom, lessThanOrEqualTo(tester.getRect(find.byKey(const Key('hud.gauge'))).bottom));
    await tester.tap(find.byKey(const Key('scene.retreat')));
    await tester.pump();
    expect(log.sent.whereType<RetreatTower>(), hasLength(1));
  });

  testWidgets('러시 전투 중 띠 "Boss 3/5 · 1:42"', (tester) async {
    final t = GameTables.load();
    final s = _state();
    final ticks = (102 * 1000 / t.waves.tickMs).round();
    await pumpGame(
      tester,
      s.copyWith(
        battle: s.battle!.copyWith(rush: RushView(index: 2, total: 5, ticks: ticks)),
      ),
      openTab: false,
    );
    expect(find.text('Boss 3/5 · 1:42'), findsOneWidget);
  });

  testWidgets('결과: TowerEnded(timeout) → 창 "Time\'s up — F12 reached" · TowerSwept → 토스트 · RushEnded(cleared) → 창', (
    tester,
  ) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _state();
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(
      RecordedTick(s.battle!, const [
        TowerEnded(1, floor: 12, reason: 'timeout', kills: 340, chestGems: 25, chestCards: 1),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tower.result')), findsOneWidget);
    expect(find.text("Time's up — F12 reached"), findsOneWidget);
    expect(find.text('Gems 25'), findsOneWidget);
    expect(find.text('Cards ×1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scene.result.ok')));
    await tester.pumpAndSettle();
    feed.add(RecordedTick(s.battle!, const [TowerSwept(2, floor: 9, chestGems: 10)]));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Swept F9 · Gems 10'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    feed.add(
      RecordedTick(s.battle!, const [RushEnded(3, killed: 5, ticks: 2000, reason: 'cleared', gems: 85, best: true)]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rush.result')), findsOneWidget);
    expect(find.text('New record!'), findsOneWidget);
  });

  test('처음 열림 안내: 탑 상태가 생기면 guide.scenes · 패스 1단계면 guide.pass', () {
    final t = GameTables.load();
    final closed = loadFixture('stage37_midgame');
    expect(activeGuides(closed, t), isNot(contains('guide.scenes')));
    expect(activeGuides(_state(), t), contains('guide.scenes'));
    final pass = closed.copyWith(
      pass: PassState(season: t.iap.pass.season, xp: t.iap.pass.xpPerLevel),
    );
    expect(activeGuides(pass, t), contains('guide.pass'));
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);

    testWidgets('항해 탭 탑·러시 카드 ko s24', (tester) async {
      final t = GameTables.load();
      await pumpGame(
        tester,
        _state(bestTicks: (150 * 1000 / t.waves.tickMs).round(), claimed: [0]),
        locale: const Locale('ko'),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('rush.card')),
        200,
        scrollable: find.descendant(of: find.byKey(const Key('sheet.panel')), matching: find.byType(Scrollable)).first,
      );
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_scene_cards_s24.png'));
    });

    testWidgets('탑 전투 띠 + 결과 창 ko s24', (tester) async {
      final feed = StreamController<RecordedTick>.broadcast(sync: true);
      addTearDown(feed.close);
      final s = _state();
      final on = s.copyWith(battle: s.battle!.copyWith(tower: const TowerView(floor: 12, wave: 1, waves: 3)));
      await pumpGame(
        tester,
        on,
        openTab: false,
        locale: const Locale('ko'),
        overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
      );
      feed.add(
        RecordedTick(on.battle!, const [
          TowerEnded(1, floor: 12, reason: 'sunk', kills: 340, chestGems: 25, chestCards: 1),
        ]),
      );
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_tower_result_s24.png'));
    });
  });
}

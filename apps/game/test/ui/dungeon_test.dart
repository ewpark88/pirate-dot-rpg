import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/widgets/reward_burst.dart';

import 'ui_harness.dart';

// 요일 던전 (S5 계약 platform-weekday-dungeon · 경제 dungeon.dart): 항해 탭 카드(오늘 계열 · 단계 1~10 · 보상 · 임시 출전 ·
// 도전·소탕), 전투 띠 · 후퇴, 클리어 창 · 실패 창(도전권 돌려받음) · 소탕 토스트.

final _t = GameTables.load();
const _tall = Size(400, 2000);

/// 오늘(시험 시계 = 저장 시각) 묶음에서 [cleared]단계까지 깸, 도전권 [tickets].
GameState _state({int cleared = 3, int tickets = 2}) {
  final s = loadFixture('stage37_midgame').copyWith();
  final base = s.copyWith(progress: s.progress.copyWith(bestStage: 80));
  final g = dungeonToday(base, _t, base.savedAt).str('id');
  return base.copyWith(
    dungeon: DungeonState(tickets: tickets, refilledOn: '2026-10-12', cleared: {g: cleared}),
  );
}

void main() {
  testWidgets('카드: 4단계가 열림 · 보상 "카드 4장 · 젬 4" · 도전 → StartDungeon(4) · 2단계 고르면 도전 2 · 소탕 3', (tester) async {
    final s = _state();
    final log = await pumpGame(tester, s, size: _tall);
    await tester.ensureVisible(find.byKey(const Key('dungeon.card')));
    await tester.pump();
    expect(find.text('Crew cards ×4 · Gems 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dungeon.start')));
    await tester.tap(find.byKey(const Key('dungeon.step.2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dungeon.start')));
    await tester.tap(find.byKey(const Key('dungeon.sweep')));
    await tester.pump();
    final crewsOk = dungeonCrews(s, _t, dungeonToday(s, _t, s.savedAt)).isNotEmpty;
    expect(log.sent.map((c) => c.toJson()), [
      if (crewsOk) const StartDungeon(4).toJson(),
      if (crewsOk) const StartDungeon(2).toJson(),
      const SweepDungeon(3).toJson(),
    ]);
  });

  testWidgets('전투 중 띠 "Dungeon step 3 · wave 1/2" · 후퇴 → RetreatDungeon', (tester) async {
    final s = _state();
    final on = s.copyWith(
      battle: s.battle!.copyWith(dungeon: const DungeonView(group: 'mon', step: 3, wave: 0, waves: 2)),
    );
    final log = await pumpGame(tester, on, openTab: false);
    expect(find.text('Dungeon step 3 · wave 1/2'), findsOneWidget);
    expect(find.byKey(const Key('boss.challenge')), findsNothing);
    await tester.tap(find.byKey(const Key('scene.retreat')));
    await tester.pump();
    expect(log.sent.whereType<RetreatDungeon>(), hasLength(1));
  });

  testWidgets('끝: 클리어 창 · 실패 창(도전권 돌려받음) · 소탕 토스트', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _state();
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(
      RecordedTick(s.battle!, const [
        DungeonCleared(1, group: 'mon', step: 4, cards: ['octo', 'octo'], gems: 4),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Step 4 cleared!'), findsOneWidget);
    expect(find.text('Gems 4'), findsOneWidget);
    expect(find.text('Cards ×2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scene.result.ok')));
    await tester.pumpAndSettle();
    feed.add(RecordedTick(s.battle!, const [DungeonFailed(2, group: 'mon', step: 5, reason: 'timeout')]));
    await tester.pumpAndSettle();
    expect(find.text("Time's up"), findsOneWidget);
    expect(find.text('Your ticket was returned'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scene.result.ok')));
    await tester.pumpAndSettle();
    feed.add(RecordedTick(s.battle!, const [DungeonCleared(3, group: 'mon', step: 3, gems: 3, swept: true)]));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RewardBurst), findsOneWidget); // 소탕 = 보상 터짐
    await tester.pump(const Duration(seconds: 4));
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in const [
      ('360', Size(360, 640), 3.0),
      ('384', s24Size, s24Dpr),
      ('411', Size(411, 891), 2.625),
      ('tablet', Size(800, 1280), 2.0),
    ]) {
      testWidgets('요일 던전 카드 ko $name', (tester) async {
        await pumpGame(tester, _state(), size: size, dpr: dpr, locale: const Locale('ko'));
        await tester.scrollUntilVisible(
          find.byKey(const Key('dungeon.card')),
          200,
          scrollable: find
              .descendant(of: find.byKey(const Key('sheet.panel')), matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_dungeon_$name.png'));
      });
    }
  });
}

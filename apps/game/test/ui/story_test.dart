import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/story/story_data.dart';

import 'ui_harness.dart';

// 시나리오 골격 (사용자 2026-10-17, S2 story.json 전 가짜 대본): 처음 오프닝 컷(톡 → 다음 · 건너뛰기) ·
// 보스가 처음 나오면 아래 대화창(2.8초 자동 넘김 · 톡 → 다음 · 건너뛰기 · 한 번만).

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('384', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

Future<StreamController<RecordedTick>> _pump(
  WidgetTester tester,
  GameState s, {
  Size size = s24Size,
  double dpr = s24Dpr,
  Locale locale = const Locale('en'),
}) async {
  final feed = StreamController<RecordedTick>.broadcast(sync: true);
  addTearDown(feed.close);
  await pumpGame(
    tester,
    s,
    openTab: false,
    size: size,
    dpr: dpr,
    locale: locale,
    story: true,
    overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
  );
  return feed;
}

GameState _seenOpening(GameState s) => withGuidesSeen(s).copyWith(
  settings: Settings.fromJson({
    ...withGuidesSeen(s).settings.toJson(),
    'battleView': s.settings.battleView,
    'hints': [...withGuidesSeen(s).settings.hints, storyOpeningHint],
  }),
);

void main() {
  testWidgets('오프닝: 처음이면 컷 5장, 톡 → 다음 컷, 마지막 톡 → 닫힘 · 건너뛰기 → 바로 닫힘', (tester) async {
    await _pump(tester, loadFixture('new_player'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('opening')), findsOneWidget);
    expect(find.byKey(const Key('opening.cut.0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('opening')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('opening.cut.1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('opening.skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('opening')), findsNothing);
  });

  testWidgets('보스 대화: 처음 나온 보스면 대화창, 2.8초 뒤 다음 줄(옥토), 톡하면 닫힘 · 같은 보스 두 번째엔 없음', (tester) async {
    final s = _seenOpening(loadFixture('stage37_midgame'));
    final feed = await _pump(tester, s);
    await tester.pumpAndSettle();
    feed.add(RecordedTick(s.battle!, const [BossSpawned(1, kind: 'sea_croc', timeLimitTicks: 600)]));
    await tester.pump();
    expect(find.text('Who dares sail into MY sea?!'), findsOneWidget);
    await tester.pump(storyLineFor);
    expect(find.text("Our ship won't lose! Crew, ready the cannons!"), findsOneWidget);
    await tester.tap(find.byKey(const Key('story.dialogue')));
    await tester.pump();
    expect(find.byKey(const Key('story.dialogue')), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  for (final (name, size, dpr) in _devices) {
    testWidgets('골든: 오프닝 첫 컷 · 보스 대화창 ko $name', (tester) async {
      await loadGoldenFonts();
      await _pump(tester, loadFixture('new_player'), size: size, dpr: dpr, locale: const Locale('ko'));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_story_opening_$name.png'));

      final s = _seenOpening(loadFixture('stage37_midgame'));
      final feed = await _pump(tester, s, size: size, dpr: dpr, locale: const Locale('ko'));
      await tester.pumpAndSettle();
      feed.add(RecordedTick(s.battle!, const [BossSpawned(1, kind: 'sea_croc', timeLimitTicks: 600)]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_story_boss_$name.png'));
      await tester.pump(const Duration(seconds: 6));
    });
  }
}

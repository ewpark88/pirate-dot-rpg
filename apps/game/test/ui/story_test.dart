import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/story/story_data.dart';
import 'package:pirate_dot/ui/story/story_layer.dart' show bossEntryWait;

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

final _t = GameTables.load();

void main() {
  test('story.json의 대사 키가 모두 글로 바뀐다(story_text)', () async {
    final l = await AppLocalizations.delegate.load(const Locale('ko'));
    final script = TableStoryScript(_t);
    expect(script.opening(l), hasLength(_t.story.opening.length));
    for (final id in _t.regions.bosses.keys) {
      script
        ..bossIntro(l, id, 1)
        ..bossIntro(l, id, 7);
    }
  });

  testWidgets('오프닝: 처음이면 컷 5장, 톡 → 다음 컷, 한 컷 시간 뒤 저절로 다음 · 건너뛰기 → 바로 닫힘', (tester) async {
    // 배경 그림이 움직여 pumpAndSettle은 시간을 계속 흘린다(컷이 저절로 넘어감) — 정해진 시간만 흘린다.
    await _pump(tester, loadFixture('new_player'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('opening')), findsOneWidget);
    expect(find.byKey(const Key('opening.cut.0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('opening')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('opening.cut.1')), findsOneWidget);
    await tester.pump(TableStoryScript(_t).cutFor);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('opening.cut.2')), findsOneWidget, reason: '한 컷 시간 뒤 저절로 다음');
    await tester.tap(find.byKey(const Key('opening.skip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('opening')), findsNothing);
  });

  testWidgets('보스 대화: 처음 나온 보스면 대화창, 2.8초 뒤 다음 줄(옥토), 톡하면 닫힘 · 같은 보스 두 번째엔 없음', (tester) async {
    final s = _seenOpening(loadFixture('stage37_midgame'));
    final feed = await _pump(tester, s);
    await tester.pumpAndSettle();
    feed.add(RecordedTick(s.battle!, const [BossSpawned(1, kind: 'sea_croc', timeLimitTicks: 600)]));
    await tester.pump(bossEntryWait);
    // 대본은 story.json(S2): 고유 대사가 없으면 첫 특성의 공용 대사.
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final lines = TableStoryScript(_t).bossIntro(l, 'sea_croc', s.progress.stage);
    expect(lines.length, greaterThanOrEqualTo(2));
    expect(find.text(lines[0].text), findsOneWidget);
    await tester.pump(TableStoryScript(_t).lineFor);
    expect(find.text(lines[1].text), findsOneWidget);
    await tester.tap(find.byKey(const Key('story.dialogue')));
    await tester.pump();
    expect(find.byKey(const Key('story.dialogue')), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  for (final (name, size, dpr) in _devices) {
    testWidgets('골든: 오프닝 첫 컷 · 보스 대화창 ko $name', (tester) async {
      await loadGoldenFonts();
      await _pump(tester, loadFixture('new_player'), size: size, dpr: dpr, locale: const Locale('ko'));
      await tester.pump(const Duration(milliseconds: 400));
      await precacheImages(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_story_opening_$name.png'));

      final s = _seenOpening(loadFixture('stage37_midgame'));
      final feed = await _pump(tester, s, size: size, dpr: dpr, locale: const Locale('ko'));
      await tester.pumpAndSettle();
      feed.add(RecordedTick(s.battle!, const [BossSpawned(1, kind: 'sea_croc', timeLimitTicks: 600)]));
      await tester.pump(bossEntryWait);
      await tester.pump(const Duration(milliseconds: 300));
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_story_boss_$name.png'));
      await tester.pump(const Duration(seconds: 6));
    });
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/battle_feed.dart';

import 'ui_harness.dart';

// 보스 등장 이름표 (S1 2026-10-16): 이름 · 해역 · '대보스'/'중간 보스' 띠, 2초.

final _t = GameTables.load();

GameState _at(int stage) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(progress: s.progress.copyWith(stage: stage));
}

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

Future<StreamController<RecordedTick>> _pump(
  WidgetTester tester,
  int stage, {
  Size? size,
  double? dpr,
  Locale locale = const Locale('en'),
}) async {
  final feed = StreamController<RecordedTick>.broadcast(sync: true);
  addTearDown(feed.close);
  final s = _at(stage);
  await pumpGame(
    tester,
    s,
    size: size ?? s24Size,
    dpr: dpr ?? s24Dpr,
    locale: locale,
    openTab: false,
    overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
  );
  feed.add(RecordedTick(s.battle!, [BossSpawned(1, kind: _t.regions.bossAt(stage).id, timeLimitTicks: 600)]));
  await tester.pump();
  return feed;
}

void main() {
  testWidgets('일반 보스: 이름·해역, 띠 없음 · 2초 뒤 사라짐', (tester) async {
    await _pump(tester, 37);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('boss.intro')), findsOneWidget);
    expect(find.byKey(const Key('boss.intro.tag')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('boss.intro')), findsNothing);
  });

  testWidgets('해역 마지막 스테이지(50) = 대보스 띠 · 25 = 중간 보스 띠', (tester) async {
    await _pump(tester, 50);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('REGION BOSS'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    final mid = _t.regions.midBossEvery;
    await _pump(tester, mid);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('MID-BOSS'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);

    for (final (name, size, dpr) in _devices) {
      testWidgets('대보스 이름표 $name', (tester) async {
        await _pump(tester, 50, size: size, dpr: dpr, locale: const Locale('ko'));
        await precacheImages(tester);
        await tester.pump(const Duration(milliseconds: 700));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_boss_intro_$name.png'));
        await tester.pump(const Duration(seconds: 2));
      });
    }
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/hud/reward_gate.dart';
import 'package:pirate_dot/ui/widgets/reward_burst.dart';

import 'ui_harness.dart';

// 보상 터짐 붙이기(디자인 개편 ③): 상자(ChestOpened — 전장 연출 0.6초 뒤) · 도감 수집 보상(바로). 보스는 boss_damage_test.

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

Future<StreamController<RecordedTick>> _pump(WidgetTester tester, {Size size = s24Size, double dpr = s24Dpr}) async {
  final feed = StreamController<RecordedTick>.broadcast(sync: true);
  addTearDown(feed.close);
  await pumpGame(
    tester,
    loadFixture('stage37_midgame'),
    size: size,
    dpr: dpr,
    locale: const Locale('ko'),
    openTab: false,
    overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
  );
  return feed;
}

void main() {
  testWidgets('상자: 전장 연출 0.6초 뒤 보상 터짐(금화 칸), 누르면 닫힘 · 빠른 항해 중엔 안 뜸', (tester) async {
    final feed = await _pump(tester);
    final view = loadFixture('stage37_midgame').battle!;
    feed.add(RecordedTick(view, [ChestOpened(9, gold: BigNum.from(52000))]));
    await tester.pump(chestBurstDelay - const Duration(milliseconds: 100));
    expect(find.byKey(const Key('reward.burst')), findsNothing, reason: 'S3 전장 연출이 먼저');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reward.burst')), findsOneWidget);
    expect(find.byKey(const Key('reward.item.0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reward.burst')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reward.burst')), findsNothing);
    final sailing = BattleView.fromJson({
      ...view.toJson(),
      'fastSail': const FastSailView(from: 10, to: 40, combo: 2, phase: 'rush', speed: 2).toJson(),
    });
    feed.add(RecordedTick(sailing, [ChestOpened(10, gold: BigNum.from(5))]));
    await tester.pump(chestBurstDelay * 2);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reward.burst')), findsNothing);
  });

  testWidgets('도감 수집 보상: 바로 터짐(젬·소환권 칸), 저절로 닫힘', (tester) async {
    final feed = await _pump(tester);
    feed.add(
      RecordedTick(loadFixture('stage37_midgame').battle!, const [
        CollectionRewardClaimed(9, at: 10, gems: 100, summons: 1),
      ]),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reward.burst')), findsOneWidget);
    expect(find.byKey(const Key('reward.item.1')), findsOneWidget);
    await tester.pump(RewardBurst.duration * 2);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reward.burst')), findsNothing);
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in _devices) {
      testWidgets('상자 보상 터짐 $name', (tester) async {
        final feed = await _pump(tester, size: size, dpr: dpr);
        feed.add(RecordedTick(loadFixture('stage37_midgame').battle!, [ChestOpened(9, gold: BigNum.from(52000))]));
        await tester.pump(chestBurstDelay);
        await tester.pumpAndSettle();
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_reward_chest_$name.png'));
        await tester.tap(find.byKey(const Key('reward.burst')));
        await tester.pumpAndSettle();
      });
    }
  });
}

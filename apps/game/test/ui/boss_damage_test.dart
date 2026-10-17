import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/hud/boss_damage.dart';

import 'ui_harness.dart';

// 선원별 피해 (사용자 피드백 #13 선원 칸 피해량 · #14 보스 처치 창 — BattleView.crewDamage, BossCleared.crewDamage·mvp).

GameState _state() {
  final s = loadFixture('stage37_midgame');
  final ids = [for (final f in s.battle!.fleet) f.crewId];
  return s.copyWith(
    battle: BattleView.fromJson({
      ...s.battle!.toJson(),
      'crewDamage': {for (final (i, id) in ids.indexed) id: BigNum.parse('${(i + 1) * 12}e3').toJson()},
    }),
  );
}

BossCleared _cleared(GameState s) {
  final ids = [for (final f in s.battle!.fleet) f.crewId];
  return BossCleared(
    9,
    stage: 37,
    gems: 5,
    crewDamage: {for (final (i, id) in ids.indexed) id: BigNum.from(1000 * (i + 1))},
    mvp: ids.last,
  );
}

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

void main() {
  testWidgets('#13 선원 칸 아래 이번 스테이지 피해량(줄임 표기)', (tester) async {
    final s = _state();
    await pumpGame(tester, s, openTab: false);
    await tester.pumpAndSettle();
    final first = s.battle!.fleet.first.crewId;
    expect(find.byKey(Key('fleet.damage.$first')), findsOneWidget);
    expect(find.descendant(of: find.byKey(Key('fleet.damage.$first')), matching: find.text('DMG 12K')), findsOneWidget);
  });

  testWidgets('#14 보스 처치 → 보상 연출 뒤 창(MVP·선원 줄), 누르면 닫힘', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _state();
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(RecordedTick(s.battle!, [_cleared(s)]));
    await tester.pump(bossDamageDelay - const Duration(milliseconds: 100));
    expect(find.byKey(const Key('bossDamage')), findsNothing, reason: '보상 연출 동안은 안 뜬다');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await _passBurst(tester);
    expect(find.byKey(const Key('bossDamage')), findsOneWidget);
    expect(find.byKey(const Key('bossDamage.mvp')), findsOneWidget);
    expect(find.byKey(Key('bossDamage.row.${s.battle!.fleet.first.crewId}')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bossDamage')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bossDamage')), findsNothing);
  });

  testWidgets('#14 몇 초 뒤 저절로 닫힘 · 빠른 항해 중엔 안 뜸', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _state();
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(RecordedTick(s.battle!, [_cleared(s)]));
    await tester.pump(bossDamageDelay);
    await tester.pumpAndSettle();
    await _passBurst(tester);
    expect(find.byKey(const Key('bossDamage')), findsOneWidget);
    await tester.pump(bossDamageHold);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bossDamage')), findsNothing);
    final sailing = BattleView.fromJson({
      ...s.battle!.toJson(),
      'fastSail': const FastSailView(from: 10, to: 40, combo: 2, phase: 'rush', speed: 2).toJson(),
    });
    feed.add(RecordedTick(sailing, [_cleared(s)]));
    await tester.pump(bossDamageDelay);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bossDamage')), findsNothing);
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in _devices) {
      testWidgets('보스 처치 선원별 피해 $name', (tester) async {
        final feed = StreamController<RecordedTick>.broadcast(sync: true);
        addTearDown(feed.close);
        final s = _state();
        await pumpGame(
          tester,
          s,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
          openTab: false,
          overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
        );
        feed.add(RecordedTick(s.battle!, [_cleared(s)]));
        await tester.pump(bossDamageDelay);
        await tester.pumpAndSettle();
        await _passBurst(tester);
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_boss_damage_$name.png'));
        await tester.pump(bossDamageHold);
        await tester.pumpAndSettle();
      });
    }
  });
}

/// 보스 보상 터짐(디자인 개편 ③)이 처치 창 전에 뜬다 — 있는지 보고 눌러 닫는다.
Future<void> _passBurst(WidgetTester tester) async {
  expect(find.byKey(const Key('reward.burst')), findsOneWidget, reason: '처치 창 전 보상 터짐');
  await tester.tap(find.byKey(const Key('reward.burst')));
  // 터짐을 누르면 기다리지 않고 바로 처치 창(S4 ⑤) — 창 열림 애니메이션 한 번이면 뜬다.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const Key('bossDamage')), findsOneWidget, reason: '터짐을 누르면 바로 처치 창');
  await tester.pumpAndSettle();
}

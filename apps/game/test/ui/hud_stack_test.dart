import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';

import 'ui_harness.dart';

// S1 ① 2026-10-16: 피버·돌발 이벤트·도전·현상금·보스 실패 안내가 한꺼번에 떠도 서로 겹치지 않고, 우선순위대로 보인다.

GameState _busy() {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    progress: s.progress.copyWith(farming: true, bossFails: 1),
    battle: s.battle!.copyWith(
      seaEvent: const SeaEventView(id: 'goldfish', ticksLeft: 120),
      challenge: const ChallengeView(id: 'kills', target: 50, value: 37, ticksLeft: 200),
      fever: 1,
      feverTicksLeft: 80,
      chest: const ChestView(x: 150, y: 200, ticksLeft: 400),
      shipX: 135,
      shipY: 240,
    ),
  );
}

/// 위쪽에 떠 있는 것들 — 화면에 있는 것만.
const _top = [
  'hud.gauge',
  'boss.weak',
  // 돌발 이벤트(fun.sea.*)는 hud.gauge 안 아이콘이라 따로 세지 않는다.
  'fun.challenge.kills',
  'bounty.strip',
  'fun.fever.on',
  'bossFail.close',
  'boss.challenge',
  'fleet.crew.0',
  'fleet.crew.1',
];

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

Future<StreamController<RecordedTick>> _pumpBusy(WidgetTester tester, Size size, double dpr, {Locale? locale}) async {
  final feed = StreamController<RecordedTick>.broadcast(sync: true);
  addTearDown(feed.close);
  final s = _busy();
  await pumpGame(
    tester,
    s,
    size: size,
    dpr: dpr,
    locale: locale ?? const Locale('en'),
    openTab: false,
    overrides: [
      battleFeedProvider.overrideWithValue(feed.stream),
      adOfferProvider.overrideWith((ref, _) => true),
    ],
  );
  feed.add(RecordedTick(s.battle!, const [BossFailed(1, stage: 37)]));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return feed;
}

void _expectNoOverlap(WidgetTester tester, String name) {
  final rects = <String, Rect>{
    for (final k in _top)
      if (find.byKey(Key(k)).evaluate().isNotEmpty) k: tester.getRect(find.byKey(Key(k)).first),
  };
  final keys = rects.keys.toList();
  for (var i = 0; i < keys.length; i++) {
    for (var j = i + 1; j < keys.length; j++) {
      final o = rects[keys[i]]!.intersect(rects[keys[j]]!);
      expect(
        o.width > 1 && o.height > 1,
        isFalse,
        reason: '$name: ${keys[i]} ${rects[keys[i]]} ↔ ${keys[j]} ${rects[keys[j]]}',
      );
    }
  }
}

void main() {
  for (final (name, size, dpr) in _devices) {
    testWidgets('한꺼번에 떠도 겹치지 않음 $name', (tester) async {
      await _pumpBusy(tester, size, dpr);
      expect(tester.takeException(), isNull);
      // 알약은 한 묶음(우선순위: 현상금 > 도전 > 화물칸) — 돌발 이벤트는 띠 안 작은 아이콘(실기기 ④).
      expect(find.byKey(const Key('fun.challenge.kills')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('hud.gauge')), matching: find.byKey(const Key('fun.sea.goldfish'))),
        findsOneWidget,
      );
      expect(find.byKey(const Key('fun.fever.on')), findsOneWidget);
      _expectNoOverlap(tester, name);
      await tester.pump(const Duration(seconds: 10));
    });
  }

  testWidgets('피버가 아니어도 돌발 이벤트는 띠 안 아이콘 · 도전 알약', (tester) async {
    final s = _busy();
    await pumpGame(tester, s.copyWith(battle: s.battle!.copyWith(feverTicksLeft: 0)), openTab: false);
    expect(find.byKey(const Key('fun.sea.goldfish')), findsOneWidget);
    expect(find.byKey(const Key('fun.challenge.kills')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);

    for (final (name, size, dpr) in _devices) {
      testWidgets('한꺼번에 $name', (tester) async {
        await _pumpBusy(tester, size, dpr, locale: const Locale('ko'));
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_hud_stack_$name.png'));
        await tester.pump(const Duration(seconds: 10));
      });
    }
  });
}

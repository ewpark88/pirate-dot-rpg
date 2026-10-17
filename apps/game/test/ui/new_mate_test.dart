import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/crew/new_mate.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/home_screen.dart';

import 'ui_harness.dart';

// 수집의 재미(사용자 2026-10-17): 새 동료 합류 → 연출 뒤 '새 동료!' 카드 — 역할·싸우는 법·출전시키기·도감 진행.

void main() {
  final t = GameTables.load();

  test('역할 = 표 crews[].role — 40명 모두 배지가 있다', () {
    for (final c in t.crews.crews) {
      expect(crewRoleOf(t, c.id).name, c.role, reason: c.id);
    }
  });

  testWidgets('CardGranted(isNew) → 연출 뒤 카드, 빈 칸 있으면 [출전시키기] → SetFleetSlot', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('new_player');
    final log = await pumpGame(
      tester,
      s,
      openTab: false,
      overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
    );
    final newId = t.crews.crews.firstWhere((c) => !s.crews.containsKey(c.id)).id;
    feed.add(RecordedTick(s.battle!, [CardGranted(3, crewId: newId, rarity: 'rare', source: 'boss', isNew: true)]));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('newMate')), findsNothing, reason: 'S3 앞면 공개 연출 동안은 기다린다');
    await tester.pump(newMateDelay);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('newMate')), findsOneWidget);
    expect(find.byKey(const Key('newMate.how')), findsOneWidget);
    expect(find.byKey(const Key('newMate.dex')), findsOneWidget);
    await tester.tap(find.byKey(const Key('newMate.deploy')));
    await tester.pumpAndSettle();
    expect(log.sent.whereType<SetFleetSlot>().single.crewId, newId);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('이미 있는 선원 카드(isNew false)는 카드 없음', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(RecordedTick(s.battle!, [CardGranted(3, crewId: s.crews.keys.first, rarity: 'common', source: 'boss')]));
    await tester.pump(newMateDelay + const Duration(seconds: 1));
    expect(find.byKey(const Key('newMate')), findsNothing);
  });

  for (final (name, size, dpr, lang) in [
    ('360', const Size(360, 640), 3.0, 'ko'),
    ('s24', s24Size, s24Dpr, 'en'),
    ('tablet', const Size(800, 1280), 2.0, 'ko'),
  ]) {
    testWidgets('골든: 새 동료 카드 $lang $name', (tester) async {
      await loadGoldenFonts();
      final feed = StreamController<RecordedTick>.broadcast(sync: true);
      addTearDown(feed.close);
      final s = loadFixture('new_player');
      await pumpGame(
        tester,
        s,
        openTab: false,
        size: size,
        dpr: dpr,
        locale: Locale(lang),
        overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
      );
      feed.add(
        RecordedTick(s.battle!, const [CardGranted(3, crewId: 'king', rarity: 'rare', source: 'boss', isNew: true)]),
      );
      await tester.pump(newMateDelay);
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/${lang}_new_mate_$name.png'));
    });
  }

  testWidgets('환영 카드(starter) 순간: 열린 시트를 닫고 가이드 말을 연출 동안 접는다 (S3 c12ced0a)', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('new_player');
    await pumpGame(tester, s, tab: shipTabIndex, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    expect(find.byKey(const Key('sheet.panel')), findsOneWidget);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    feed.add(
      RecordedTick(s.battle!, const [CardGranted(3, crewId: 'bones', rarity: 'rare', source: 'starter', isNew: true)]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('sheet.panel')), findsNothing, reason: '시트가 닫혀 전장이 넓게');
    expect(c.read(guideHoldProvider), isTrue);
    await tester.pump(newMateDelay);
    expect(c.read(guideHoldProvider), isFalse);
    await tester.pumpAndSettle();
  });
}

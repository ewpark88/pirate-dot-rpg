import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 사용자 질문 2026-10-16: 파란 새로고침 버튼(보스 도전)·빠른 강화가 무엇인지 보이게. 궁극기 버튼은 2026-10-17 제거.

GameState _with({bool farming = false, BigNum? gold}) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    progress: s.progress.copyWith(farming: farming),
    wallet: gold == null ? null : s.wallet.copyWith(gold: gold),
  );
}

void main() {
  testWidgets('궁극기 버튼·함성 게이지 없음 (사용자 결정 2026-10-17 — 피버 첫 일격으로 흡수)', (tester) async {
    await pumpGame(tester, _with(), openTab: false);
    for (final key in ['hud.ultimate', 'hud.ult.ring', 'hud.ult.tag', 'hud.ult.tap', 'hud.ult.bubble']) {
      expect(find.byKey(Key(key)), findsNothing, reason: key);
    }
  });

  testWidgets('보스 도전: 보스 초상 + "Boss!" 버튼(버튼 위 말풍선은 가이드 v3 옥토 말로 합침), 누르면 ChallengeBoss', (tester) async {
    final log = await pumpGame(tester, _with(farming: true), openTab: false);
    expect(find.text('Boss!'), findsOneWidget);
    expect(find.byKey(const Key('boss.bubble')), findsNothing);
    await tester.tap(find.byKey(const Key('boss.challenge')));
    expect(log.sent.whereType<ChallengeBoss>(), hasLength(1));
  });

  testWidgets('빠른 강화: 비용 알약 · 골드 부족이면 "부족" · PartUpgraded → "+부품 Lv" 떠오름', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _with();
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    expect(find.byKey(const Key('quick.upgrade.cost')), findsOneWidget);
    feed.add(RecordedTick(s.battle!, const [PartUpgraded(1, part: 'cannon', level: 53)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('+Cannon Lv 53'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('quick.upgrade.float')), findsNothing);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    c.read(gameStateProvider.notifier).replace(_with(gold: BigNum.zero));
    await tester.pump();
    expect(find.textContaining('Need '), findsOneWidget);
  });

  testWidgets('처음 1회 안내는 세이브에 남는다: 옥토 "보스에 다시 도전" → MarkHint(guide.bossRetry)', (tester) async {
    final log = await pumpGame(
      tester,
      withGuidesSeenExcept(_with(farming: true), 'guide.bossRetry'),
      openTab: false,
      guides: true,
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('challenge the boss again'), findsOneWidget);
    expect(log.hints.map((c) => c.id), contains('guide.bossRetry'));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('옛 세이브에 boss.bubble을 본 기록이 있으면 옥토 보스 재도전 안내 없음', (tester) async {
    final s = _with(farming: true);
    final seen = s.copyWith(
      settings: Settings.fromJson({
        ...s.settings.toJson(),
        'battleView': s.settings.battleView,
        'hints': [...guideIds.where((id) => id != 'guide.bossRetry'), 'boss.bubble'],
      }),
    );
    await pumpGame(tester, seen, openTab: false, guides: true);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('talk')), findsNothing, reason: '예전 boss.bubble을 봤으면 옥토도 다시 말하지 않는다');
    expect(find.byKey(const Key('boss.challenge')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);

    for (final (name, size, dpr) in [
      ('360', const Size(360, 640), 3.0),
      ('s24', s24Size, s24Dpr),
      ('411', const Size(411, 891), 2.625),
      ('tablet', const Size(800, 1280), 2.0),
    ]) {
      testWidgets('보스 도전 $name', (tester) async {
        await pumpGame(
          tester,
          _with(farming: true),
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
          openTab: false,
        );
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_hud_buttons_$name.png'));
        await tester.pump(const Duration(seconds: 5));
      });
    }
  });
}

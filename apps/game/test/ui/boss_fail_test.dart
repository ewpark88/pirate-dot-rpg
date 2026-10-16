import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 보스 실패 안내·파밍 표시 (사용자 질문 "지는 판단이 뭐냐", S1 지시 2026-10-15).

GameState _farming() {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(progress: s.progress.copyWith(farming: true));
}

void _fail(StreamController<RecordedTick> feed, GameState s) =>
    feed.add(RecordedTick(s.battle!, const [BossFailed(1, stage: 37)]));

void main() {
  testWidgets('처음 실패: 자세히(규칙 한 줄 + 추천 강화 + 보스 도전), 두 번째부터 짧게', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _farming();
    final log = await pumpGame(
      tester,
      s,
      openTab: false,
      overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
    );
    _fail(feed, s);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bossFail.detailed')), findsOneWidget);
    expect(find.textContaining('Beat the boss before time runs out'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bossFail.upgrade')));
    await tester.pump();
    expect(log.sent.whereType<UpgradePart>(), hasLength(1));
    await tester.tap(find.byKey(const Key('bossFail.close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bossFail.detailed')), findsNothing);

    // 두 번째 실패: 경제 누계 bossFails 2 → 짧게.
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    container.read(gameStateProvider.notifier).replace(s.copyWith(progress: s.progress.copyWith(bossFails: 2)));
    await tester.pump();
    _fail(feed, s);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bossFail.short')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bossFail.challenge')));
    await tester.pumpAndSettle();
    expect(log.sent.whereType<ChallengeBoss>(), hasLength(1));
    expect(find.byKey(const Key('bossFail.short')), findsNothing);
  });

  testWidgets('짧은 안내는 4초 뒤 저절로 사라지고, 파밍이 끝나면 바로 닫힌다', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _farming();
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    _fail(feed, s);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bossFail.detailed')), findsNothing);

    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final again = s.copyWith(progress: s.progress.copyWith(bossFails: 3));
    container.read(gameStateProvider.notifier).replace(again);
    await tester.pump();
    _fail(feed, s);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bossFail.short')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bossFail.short')), findsNothing);
    _fail(feed, s);
    await tester.pumpAndSettle();
    container
        .read(gameStateProvider.notifier)
        .replace(again.copyWith(progress: again.progress.copyWith(farming: false)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bossFail.short')), findsNothing);
  });

  testWidgets('파밍 중 띠: 파밍이면 보이고 아니면 없다', (tester) async {
    await pumpGame(tester, _farming(), openTab: false);
    expect(find.byKey(const Key('hud.farming')), findsOneWidget); // 게이지 안 꼬리표
    await pumpGame(tester, loadFixture('stage37_midgame'), openTab: false);
    expect(find.byKey(const Key('hud.farming')), findsNothing);
  });

  testWidgets('골든: 처음 실패 안내 ko', (tester) async {
    await loadGoldenFonts();
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _farming();
    await pumpGame(
      tester,
      s,
      locale: const Locale('ko'),
      openTab: false,
      overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
    );
    await precacheImages(tester);
    _fail(feed, s);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_boss_fail.png'));
    await tester.pump(const Duration(seconds: 9));
  });
}

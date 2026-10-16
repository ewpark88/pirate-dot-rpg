import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 사용자 질문 2026-10-16: 선원 줄 옆 동그라미(궁극기)·파란 새로고침 버튼(보스 도전)·빠른 강화가 무엇인지 보이게.

GameState _with({double rage = 0.4, bool farming = false, BigNum? gold}) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    progress: s.progress.copyWith(rage: rage, farming: farming),
    wallet: gold == null ? null : s.wallet.copyWith(gold: gold),
  );
}

void main() {
  testWidgets('궁극기: 꼬리표·원형 게이지·%, 가득 차면 탭!·말풍선, 발동하면 선장·궁극기 이름 띠', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _with();
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    expect(find.byKey(const Key('hud.ult.tag')), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.byKey(const Key('hud.ult.tap')), findsNothing);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    c.read(gameStateProvider.notifier).replace(_with(rage: 1));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    expect(find.byKey(const Key('hud.ult.tap')), findsOneWidget);
    expect(find.byKey(const Key('hud.ult.bubble')), findsOneWidget);
    final captain = s.battle!.fleet.first.crewId;
    feed.add(RecordedTick(s.battle!, [UltimateCast(1, crewId: captain, ultimateId: 'ult_cannon_rain')]));
    c.read(gameStateProvider.notifier).replace(_with(rage: 0));
    await tester.pump();
    expect(find.byKey(const Key('hud.ult.banner')), findsOneWidget);
    expect(find.textContaining('Cannon Storm'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('hud.ult.banner')), findsNothing);
  });

  testWidgets('보스 도전: 보스 초상 + "Boss!" 버튼, 처음 1회 말풍선, 누르면 ChallengeBoss', (tester) async {
    final log = await pumpGame(tester, _with(farming: true), openTab: false);
    expect(find.text('Boss!'), findsOneWidget);
    expect(find.byKey(const Key('boss.bubble')), findsOneWidget);
    await tester.tap(find.byKey(const Key('boss.challenge')));
    expect(log.sent.whereType<ChallengeBoss>(), hasLength(1));
    await tester.pump(const Duration(seconds: 5)); // 말풍선 4초 뒤 닫힘
    expect(find.byKey(const Key('boss.bubble')), findsNothing);
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

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);

    for (final (name, size, dpr) in [
      ('360', const Size(360, 640), 3.0),
      ('s24', s24Size, s24Dpr),
      ('411', const Size(411, 891), 2.625),
      ('tablet', const Size(800, 1280), 2.0),
    ]) {
      testWidgets('궁극기 가득·보스 도전 $name', (tester) async {
        await pumpGame(
          tester,
          _with(rage: 1, farming: true),
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

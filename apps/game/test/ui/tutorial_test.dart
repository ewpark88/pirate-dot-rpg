import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

import 'ui_harness.dart';

GameState _step(int step) => loadFixture('new_player').copyWith(tutorialStep: step);

void main() {
  // 가이드 v3 (S1 승인 2026-10-17): 옥토 선장 말풍선 · 누를 곳 빛 테두리 + 손가락 · 밝은 곳 밖 누름은 막음 · 말은 0.7초 쉬고 나온다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('기준 8: 2단계 — 옥토 "대포를 키워 볼까요?", 빠른 강화·배 탭이 빛나고, 배 탭을 열면 대포 버튼으로 말이 바뀐다', (tester) async {
    await pumpGame(
      tester,
      loadFixture('stage37_midgame').copyWith(tutorialStep: 2),
      keepTutorial: true,
      openTab: false,
    );
    await settle(tester);
    expect(find.textContaining('power up the cannon'), findsOneWidget);
    expect(find.byKey(const Key('talk.glow.0')), findsOneWidget);
    expect(find.byKey(const Key('guide.finger')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab.$shipTab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(find.text('This button! Tap the cannon.'), findsOneWidget);
    expect(find.byKey(const Key('tutorial.spot.ship.upgrade.cannon')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('S1 결정 (a): 밝은 곳 밖(설정 톱니)을 누르면 막히고 손가락이 다시 톡톡', (tester) async {
    await pumpGame(tester, _step(2), keepTutorial: true, openTab: false);
    await settle(tester);
    await tester.tap(find.byKey(const Key('hud.settings')), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Settings'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('기준 8: 건너뛰기는 늘 있고 → "안내를 끌까요?" → 끄기 = SkipTutorial, 계속 보기 = 그대로', (tester) async {
    for (final step in [1, 2, 3, 4, 5, 6]) {
      final log = await pumpGame(tester, _step(step), keepTutorial: true, openTab: false);
      await settle(tester);
      expect(find.byKey(const Key('guide.skip')), findsOneWidget, reason: 'step $step');
      await tester.tap(find.byKey(const Key('guide.skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guide.skip.keep')));
      await tester.pumpAndSettle();
      expect(log.sent.whereType<SkipTutorial>(), isEmpty);
      await tester.tap(find.byKey(const Key('guide.skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guide.skip.off')));
      await tester.pumpAndSettle();
      expect(log.sent.last, isA<SkipTutorial>(), reason: 'step $step');
    }
  });

  testWidgets('1·6단계는 말풍선을 톡 → TutorialAck(단계)(“톡 눌러 계속”), 2단계는 직접 해 보기', (tester) async {
    var log = await pumpGame(tester, _step(1), keepTutorial: true, openTab: false);
    await settle(tester);
    expect(find.byKey(const Key('talk.next')), findsOneWidget);
    await tester.tap(find.byKey(const Key('talk.text')));
    expect(log.sent.single.toJson(), const TutorialAck(1).toJson());

    log = await pumpGame(tester, _step(6), keepTutorial: true, openTab: false);
    await settle(tester);
    await tester.tap(find.byKey(const Key('talk.text')));
    expect(log.sent.single.toJson(), const TutorialAck(6).toJson());

    await pumpGame(tester, _step(2), keepTutorial: true, openTab: false);
    await settle(tester);
    expect(find.byKey(const Key('talk.next')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3단계: 파밍 중이고 강화할 수 있으면 "배를 키우고 다시", 아니면 "보스 도전을 톡!"', (tester) async {
    final base = loadFixture('stage37_midgame');
    final fail = base.copyWith(tutorialStep: 3, progress: base.progress.copyWith(farming: true));
    await pumpGame(tester, fail, keepTutorial: true, openTab: false);
    await settle(tester);
    expect(find.textContaining('Upgrade the cannon and hull'), findsOneWidget);
    final broke = fail.copyWith(wallet: fail.wallet.copyWith(gold: BigNum.zero));
    await pumpGame(tester, broke, keepTutorial: true, openTab: false);
    await settle(tester);
    expect(find.text("We'll win this time! Tap Boss Challenge!"), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('강화하면 초록 반응 "좋아요! 대포 Lv n" 뒤 다음 말', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _step(2);
    await pumpGame(
      tester,
      s,
      keepTutorial: true,
      openTab: false,
      overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
    );
    await settle(tester);
    feed.add(RecordedTick(s.battle!, const [PartUpgraded(1, part: 'cannon', level: 2)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nice! Cannon Lv 2 — they melt faster now.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Nice!'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('4단계: 10회 소환을 가리키고, 소환은 Summon만 (Ack는 결과 창을 닫을 때 — summon_result_test)', (tester) async {
    final base = loadFixture('stage37_midgame');
    final state = base.copyWith(tutorialStep: 4, wallet: base.wallet.copyWith(gems: 1000));
    final log = await pumpGame(tester, state, tab: summonTab, keepTutorial: true);
    await settle(tester);
    expect(find.byKey(const Key('tutorial.spot.summon.ten')), findsOneWidget);
    expect(find.text('Your first 10-pull is free! Tap here!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('summon.ten')));
    expect(log.sent.map((c) => c.toJson()), [const Summon(count: 10).toJson()]);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('말풍선 글씨 18 · 누를 곳(도크 배 탭)·선원 줄을 가리지 않는다', (tester) async {
    await pumpGame(tester, _step(2), keepTutorial: true, openTab: false);
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('talk.text'))).style!.fontSize, greaterThanOrEqualTo(18));
    final talk = tester.getRect(find.byKey(const Key('talk')));
    expect(talk.overlaps(tester.getRect(find.byKey(const Key('tab.$shipTab')))), isFalse);
    expect(talk.overlaps(tester.getRect(find.byKey(const Key('fleet.crew.0')))), isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('튜토리얼이 끝나면(그리고 본 안내뿐이면) 말풍선·손가락 없음', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    await settle(tester);
    expect(find.byKey(const Key('talk')), findsNothing);
    expect(find.byKey(const Key('guide.finger')), findsNothing);
  });

  test('기준 9: 튜토리얼 중에는 광고 제안을 숨긴다 (광고가 준비돼도)', () {
    for (final (step, expected) in [(2, false), (null, true)]) {
      final container = ProviderContainer(
        overrides: [
          initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame').copyWith(clearTutorial: true)),
          tutorialStepProvider.overrideWithValue(step),
          adsPortProvider.overrideWithValue(_ReadyAds()),
        ],
      );
      expect(container.read(adOfferProvider(AdPlacement.tailwind)), expected, reason: 'step $step');
      container.dispose();
    }
  });
}

class _ReadyAds implements AdsPort {
  @override
  bool isReady(AdPlacement placement) => true;

  @override
  Future<AdResult> show(AdPlacement placement) async => AdResult.rewarded;
}

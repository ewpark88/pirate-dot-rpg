import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

import 'ui_harness.dart';

GameState _step(int step) => loadFixture('new_player').copyWith(tutorialStep: step);

void main() {
  // 가이드 v2 (docs/specs/ui-guide-v2.md): 단계마다 큰 카드(무엇 + 왜) · 가리킨 곳만 밝게 + 손가락 · 밝은 곳 밖 누름은 막음.

  testWidgets('기준 8: 2단계 — 카드 "배를 강화해요" + 왜 한 줄, 배 탭을 가리키고 누르면 대포 버튼', (tester) async {
    await pumpGame(
      tester,
      loadFixture('stage37_midgame').copyWith(tutorialStep: 2),
      keepTutorial: true,
      openTab: false,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Upgrade your ship'), findsOneWidget);
    expect(find.textContaining('stronger cannon'), findsOneWidget);
    expect(find.byKey(const Key('tutorial.spot.tab.ship')), findsOneWidget);
    expect(find.byKey(const Key('guide.finger')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab.$shipTab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('tutorial.spot.ship.upgrade.cannon')), findsOneWidget);
    expect(find.byKey(const Key('tutorial.spot.tab.summon')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('S1 결정 (a): 밝은 곳 밖(설정 톱니)을 누르면 막히고 "여기를 눌러요"', (tester) async {
    await pumpGame(tester, _step(2), keepTutorial: true, openTab: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('hud.settings')), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Settings'), findsNothing);
    expect(find.byKey(const Key('guide.nudge')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('기준 8: 건너뛰기는 늘 있고 → "안내를 끌까요?" → 끄기 = SkipTutorial, 계속 보기 = 그대로', (tester) async {
    for (final step in [1, 2, 3, 4, 5, 6]) {
      final log = await pumpGame(tester, _step(step), keepTutorial: true, openTab: false);
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

  testWidgets('1·6단계는 큰 "알겠어요" → TutorialAck(단계), 2단계는 없음(직접 해 보기)', (tester) async {
    var log = await pumpGame(tester, _step(1), keepTutorial: true, openTab: false);
    expect(tester.getSize(find.byKey(const Key('guide.ok'))).height, greaterThanOrEqualTo(56));
    await tester.tap(find.byKey(const Key('guide.ok')));
    expect(log.sent.single.toJson(), const TutorialAck(1).toJson());

    log = await pumpGame(tester, _step(6), keepTutorial: true, openTab: false);
    await tester.tap(find.byKey(const Key('guide.ok')));
    expect(log.sent.single.toJson(), const TutorialAck(6).toJson());

    await pumpGame(tester, _step(2), keepTutorial: true, openTab: false);
    expect(find.byKey(const Key('guide.ok')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('4단계: 10회 소환을 가리키고, 소환은 Summon만 (Ack는 결과 창을 닫을 때 — summon_result_test)', (tester) async {
    final base = loadFixture('stage37_midgame');
    final state = base.copyWith(tutorialStep: 4, wallet: base.wallet.copyWith(gems: 1000));
    final log = await pumpGame(tester, state, tab: summonTab, keepTutorial: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('tutorial.spot.summon.ten')), findsOneWidget);
    await tester.tap(find.byKey(const Key('summon.ten')));
    expect(log.sent.map((c) => c.toJson()), [const Summon(count: 10).toJson()]);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('카드 글씨: 제목 ≥ 22 · 왜 ≥ 18, 가리킨 곳(도크 배 탭)을 가리지 않는다', (tester) async {
    await pumpGame(tester, _step(2), keepTutorial: true, openTab: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<Text>(find.byKey(const Key('guide.title'))).style!.fontSize, greaterThanOrEqualTo(22));
    expect(tester.widget<Text>(find.byKey(const Key('guide.why'))).style!.fontSize, greaterThanOrEqualTo(18));
    final card = tester.getRect(find.byKey(const Key('guide.card')));
    final tab = tester.getRect(find.byKey(const Key('tab.$shipTab')));
    expect(card.overlaps(tab), isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('튜토리얼이 끝나면(그리고 본 안내뿐이면) 카드·손가락 없음', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.byKey(const Key('guide.card')), findsNothing);
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

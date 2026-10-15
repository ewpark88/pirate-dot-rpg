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
  testWidgets('기준 8: 2단계 — 말풍선 문구, 배 탭과 대포 버튼을 가리킨다', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame').copyWith(tutorialStep: 2), keepTutorial: true);
    expect(find.text('Try upgrading the Cannon.'), findsOneWidget);
    expect(find.byKey(const Key('tutorial.spot.tab.ship')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab.$shipTab')));
    // 시트가 올라오는 시간 (첫 프레임에 애니메이션이 시작된다).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('tutorial.spot.ship.upgrade.cannon')), findsOneWidget);
    expect(find.byKey(const Key('tutorial.spot.tab.summon')), findsNothing);
  });

  testWidgets('기준 8: 건너뛰기는 항상 보이고 → SkipTutorial', (tester) async {
    for (final step in [1, 2, 3, 4, 5, 6]) {
      final log = await pumpGame(tester, _step(step), keepTutorial: true);
      expect(find.byKey(const Key('tutorial.skip')), findsOneWidget, reason: 'step $step');
      await tester.tap(find.byKey(const Key('tutorial.skip')));
      expect(log.sent.last, isA<SkipTutorial>());
    }
  });

  testWidgets('1·6단계는 확인 버튼 → TutorialAck(단계), 2단계는 확인 버튼 없음', (tester) async {
    var log = await pumpGame(tester, _step(1), keepTutorial: true);
    await tester.tap(find.byKey(const Key('tutorial.ok')));
    expect(log.sent.single.toJson(), const TutorialAck(1).toJson());

    log = await pumpGame(tester, _step(6), keepTutorial: true);
    await tester.tap(find.byKey(const Key('tutorial.ok')));
    expect(log.sent.single.toJson(), const TutorialAck(6).toJson());

    await pumpGame(tester, _step(2), keepTutorial: true);
    expect(find.byKey(const Key('tutorial.ok')), findsNothing);
  });

  testWidgets('4단계: 10회 소환을 가리키고, 소환은 Summon만 (Ack는 결과 창을 닫을 때 — summon_result_test)', (tester) async {
    final base = loadFixture('stage37_midgame');
    final state = base.copyWith(tutorialStep: 4, wallet: base.wallet.copyWith(gems: 1000));
    final log = await pumpGame(tester, state, tab: summonTab, keepTutorial: true);
    expect(find.byKey(const Key('tutorial.spot.summon.ten')), findsOneWidget);
    await tester.tap(find.byKey(const Key('summon.ten')));
    expect(log.sent.map((c) => c.toJson()), [const Summon(count: 10).toJson()]);
  });

  testWidgets('말풍선은 위쪽(전장 위)에 — 시트와 선원 줄을 가리지 않는다', (tester) async {
    await pumpGame(tester, _step(2), keepTutorial: true);
    final bubble = tester.getRect(find.byKey(const Key('tutorial.bubble')));
    final battle = tester.getRect(find.byKey(const Key('battle.area')));
    final sheet = tester.getRect(find.byKey(const Key('sheet.handle')));
    expect(bubble.top, greaterThanOrEqualTo(battle.top));
    expect(bubble.bottom, lessThanOrEqualTo(battle.center.dy));
    expect(bubble.bottom, lessThanOrEqualTo(sheet.top));
  });

  testWidgets('튜토리얼이 끝나면 말풍선·손가락 없음', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.byKey(const Key('tutorial.bubble')), findsNothing);
    expect(find.byIcon(Icons.touch_app), findsNothing);
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/hud/fun_strips.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 지루함 해소 3종 UI (S2 c5193fa): 돌발 이벤트 띠·유리병 말풍선·즉석 도전 띠·피버 막대.

GameState _with({SeaEventView? sea, ChallengeView? challenge, double fever = 0, int feverLeft = 0}) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    battle: s.battle!.copyWith(
      seaEvent: sea,
      clearSeaEvent: sea == null,
      challenge: challenge,
      clearChallenge: challenge == null,
      fever: fever,
      feverTicksLeft: feverLeft,
    ),
  );
}

void main() {
  testWidgets('돌발 이벤트 띠: 황금 물고기 → 이름과 남은 막대, 끝나면 사라짐', (tester) async {
    await pumpGame(tester, _with(sea: const SeaEventView(id: 'goldfish', ticksLeft: 120)), openTab: false);
    expect(find.byKey(const Key('fun.sea.goldfish')), findsOneWidget);
    expect(find.text('Golden fish! Tap to catch'), findsOneWidget);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    c.read(gameStateProvider.notifier).replace(_with());
    await tester.pump();
    expect(find.byKey(const Key('fun.sea.goldfish')), findsNothing);
  });

  testWidgets('유리병: 쪽지 3장 말풍선, 누르면 PickBottle(index)', (tester) async {
    final log = await pumpGame(
      tester,
      _with(
        sea: const SeaEventView(id: 'bottle', ticksLeft: 200, choices: ['gold', 'tailwind', 'gift']),
      ),
      openTab: false,
    );
    expect(find.text('Gold pouch'), findsOneWidget);
    expect(find.text('Tailwind 10m'), findsOneWidget);
    expect(find.text('Gift'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fun.bottle.1')));
    await tester.pump();
    expect(log.sent.whereType<PickBottle>().map((c) => c.toJson()), [const PickBottle(1).toJson()]);
  });

  testWidgets('즉석 도전: 진행 글·남은 초, 성공하면 금색 + 보상, 잠시 뒤 사라짐', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _with(challenge: const ChallengeView(id: 'kills', target: 50, value: 37, ticksLeft: 400));
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    expect(find.text('Defeat 37/50'), findsOneWidget);
    expect(find.text('20s'), findsOneWidget);
    feed.add(RecordedTick(s.battle!, const [ChallengeEnded(1, id: 'kills', success: true, reward: 'gems:2')]));
    await tester.pump();
    expect(find.byKey(const Key('fun.challenge.done')), findsOneWidget);
    expect(find.text('Gems +2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('fun.challenge.done')), findsNothing);
  });

  testWidgets('피버: 평소엔 작은 막대, 발동 중엔 "Fever! n초"', (tester) async {
    await pumpGame(tester, _with(fever: 0.5), openTab: false);
    expect(find.byKey(const Key('fun.fever')), findsOneWidget);
    await pumpGame(tester, _with(feverLeft: 140), openTab: false);
    expect(find.text('Fever! 7s'), findsOneWidget);
  });

  test('보상 요약 → 글', () async {
    final l = await AppLocalizations.delegate.load(const Locale('ko'));
    expect(rewardText(l, 'gems:2'), '젬 +2');
    expect(rewardText(l, 'fever:0.3'), '피버 +30%');
    expect(rewardText(l, 'tailwind:600'), '순풍 10분');
    expect(rewardText(l, 'gold:${BigNum.from(120000)}'), '골드 +${BigNum.from(120000).format()}');
    expect(rewardText(l, null), '');
  });

  testWidgets('골든: 유리병·도전·피버 ko', (tester) async {
    await loadGoldenFonts();
    await pumpGame(
      tester,
      _with(
        sea: const SeaEventView(id: 'bottle', ticksLeft: 120, choices: ['gold', 'tailwind', 'gift']),
        challenge: const ChallengeView(id: 'kills', target: 50, value: 37, ticksLeft: 400),
        fever: 0.6,
      ),
      locale: const Locale('ko'),
      openTab: false,
    );
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_fun_events.png'));
  });
}

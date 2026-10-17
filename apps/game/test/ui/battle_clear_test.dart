import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 사용자 지시 2026-10-16 (실기기): 전장 한가운데를 덮는 전폭 흰 띠(상자 광고 줄) 금지, 피버는 극적으로.

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('S24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

/// 늘 떠 있을 수 있는 전장 위 UI (띠·알약·말풍선). 처음 한 번 뜨는 안내 카드·튜토리얼은 뺀다.
const _overlays = [
  'hud.farming',
  'fun.sea.goldfish',
  'fun.challenge.kills',
  'bounty.strip',
  'bossFail.short',
];

GameState _busy() {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    progress: s.progress.copyWith(farming: true),
    battle: s.battle!.copyWith(
      chest: const ChestView(x: 150, y: 200, ticksLeft: 400),
      shipX: 135,
      shipY: 240,
      seaEvent: const SeaEventView(id: 'goldfish', ticksLeft: 100),
      challenge: const ChallengeView(id: 'kills', target: 50, value: 10, ticksLeft: 300),
    ),
  );
}

void main() {
  for (final (name, size, dpr) in _devices) {
    testWidgets('$name: 전장 가운데 60%를 덮는 띠·알약이 없고, 전폭 불투명 띠가 없다', (tester) async {
      await pumpGame(
        tester,
        _busy(),
        size: size,
        dpr: dpr,
        openTab: false,
        overrides: [adOfferProvider.overrideWith((ref, _) => true)],
      );
      final area = tester.getRect(find.byKey(const Key('battle.area')));
      final center = Rect.fromLTRB(
        area.left + area.width * 0.2,
        area.top + area.height * 0.2,
        area.right - area.width * 0.2,
        area.bottom - area.height * 0.2,
      );
      for (final key in _overlays) {
        final f = find.byKey(Key(key));
        if (f.evaluate().isEmpty) continue;
        final r = tester.getRect(f);
        expect(r.width, lessThan(area.width * 0.9), reason: '$key 전폭');
        expect(r.overlaps(center), isFalse, reason: '$key가 전장 가운데를 덮는다 $r / $center');
      }
      // 상자 광고 알약·말풍선 없음(사용자 지시 2026-10-17 — 상자를 누르면 창).
      expect(find.byKey(const Key('chest.pill')), findsNothing);
      expect(find.byKey(const Key('chest.adBubble')), findsNothing);
      // 현상금 전투 중 (현상금 알약만).
      final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
      final busy = _busy();
      c
          .read(gameStateProvider.notifier)
          .replace(
            busy.copyWith(
              battle: busy.battle!.copyWith(bounty: const BountyView(bossId: 'kraken', tier: 2, ticksLeft: 300)),
            ),
          );
      await tester.pump();
      final strip = tester.getRect(find.byKey(const Key('bounty.strip')));
      expect(strip.overlaps(center), isFalse, reason: 'bounty.strip $strip / $center');
      // 현상금 중엔 띠 안 꼬리표(돌발 이벤트 등)를 빼고 현상금 글 + 후퇴만(사용자 2026-10-18).
      expect(find.byKey(const Key('fun.sea.goldfish')), findsNothing);
      expect(find.byKey(const Key('scene.retreat')), findsOneWidget);
    });
  }

  testWidgets('피버: 시작 때 큰 FEVER! → 0.8초 뒤 빠짐, 동안 가장자리 빛·큰 원형 게이지·남은 시간 막대·FEVER ×n, 끝나면 n마리 · +골드', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final on = s.copyWith(battle: s.battle!.copyWith(fever: 0, feverTicksLeft: 200));
    c.read(gameStateProvider.notifier).replace(on);
    feed.add(RecordedTick(on.battle!, const [FeverStarted(1, untilTick: 201)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('fun.fever.big')), findsOneWidget);
    expect(find.byKey(const Key('fun.fever.glow')), findsOneWidget);
    expect(find.byKey(const Key('fun.fever.on')), findsOneWidget);
    // 피버 v2: 게이지 안 막대는 '남은 시간'(가득에서 줄어듦) + 'FEVER ×2' 칩.
    expect(find.byKey(const Key('fun.fever.chip')), findsOneWidget);
    expect(find.text('FEVER ×2'), findsWidgets);
    feed
      ..add(RecordedTick(on.battle!, const [Kill(2, targetId: 1, gold: BigNum.zero, x: 0, y: 0)]))
      ..add(RecordedTick(on.battle!, const [Kill(3, targetId: 2, gold: BigNum.zero, x: 0, y: 0)]));
    c.read(gameStateProvider.notifier).replace(on.copyWith(battle: on.battle!.copyWith(feverTicksLeft: 100)));
    await tester.pump();
    final time = tester.widget<LinearProgressIndicator>(find.byKey(const Key('fun.fever.time')));
    expect(time.value, closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.byKey(const Key('fun.fever.big')), findsNothing);

    final off = s.copyWith(
      wallet: s.wallet.copyWith(gold: s.wallet.gold + BigNum.from(5000)),
      battle: s.battle!.copyWith(feverTicksLeft: 0),
    );
    c.read(gameStateProvider.notifier).replace(off);
    feed.add(RecordedTick(off.battle!, const [FeverEnded(300)]));
    await tester.pump();
    expect(find.byKey(const Key('fun.fever.end')), findsOneWidget);
    expect(find.textContaining('+${BigNum.from(5000).format()}'), findsOneWidget);
    expect(find.textContaining('2 defeated'), findsOneWidget); // 끝 요약: 처치 수 · 골드
    expect(find.byKey(const Key('fun.fever.glow')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('fun.fever.end')), findsNothing);
  });

  testWidgets('골든: 피버 시작 순간 ko', (tester) async {
    await loadGoldenFonts();
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('stage37_midgame');
    await pumpGame(
      tester,
      s,
      locale: const Locale('ko'),
      openTab: false,
      overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
    );
    await precacheImages(tester);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final on = s.copyWith(battle: s.battle!.copyWith(feverTicksLeft: 200));
    c.read(gameStateProvider.notifier).replace(on);
    feed.add(RecordedTick(on.battle!, const [FeverStarted(1, untilTick: 201)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_fever_start.png'));
    await tester.pump(const Duration(seconds: 2));
  });
}

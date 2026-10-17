import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 현상금 사냥 B4 UI (요청서 platform-bounty-b4 · 기획 8절 9) — 계약 B0(S2 292892a)로.

/// 2026-10-12 = 월요일(거대 소라게), 10-18 = 일요일.
FixedClock _on(int day) => FixedClock(DateTime(2026, 10, day, 12));

/// 항해 탭이 길어 현상금 카드가 첫 화면 아래에 있을 수 있다 → 세로로 긴 화면.
const _tall = Size(400, 1300);

GameState _state({
  int tickets = 3,
  Map<String, int> cleared = const {},
  Map<String, double> progress = const {},
  String? adOn,
  BountyView? active,
}) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    bounty: BountyState(tickets: tickets, refilledOn: '2026-10-12', cleared: cleared, progress: progress, adOn: adOn),
    battle: s.battle!.copyWith(bounty: active),
  );
}

Future<CommandLog> _pump(
  WidgetTester tester, {
  int day = 12,
  GameState? state,
  Size? size,
  Locale? locale,
  List<Override> overrides = const [],
}) => pumpGame(
  tester,
  state ?? _state(),
  clock: _on(day),
  size: size ?? _tall,
  locale: locale ?? const Locale('en'),
  overrides: overrides,
);

Future<void> _show(WidgetTester tester, String key) => showInSheet(tester, key);

void _replace(WidgetTester tester, GameState s) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeScreen))).read(gameStateProvider.notifier).replace(s);

void main() {
  testWidgets('카드: 월요일 = 거대 소라게·젬 보상·티켓 3/9, 도전 → StartBounty', (tester) async {
    final log = await _pump(tester);
    await _show(tester, 'bounty.card');
    expect(find.text('Tickets 3/9'), findsOneWidget);
    expect(find.text('10 gems'), findsOneWidget);
    expect(find.byKey(const Key('bounty.sweep')), findsNothing); // 아직 깬 단계 없음
    await tester.tap(find.byKey(const Key('bounty.challenge')));
    await tester.pump();
    expect(log.sent.whereType<StartBounty>().map((c) => c.toJson()), [const StartBounty('giant_hermit', 1).toJson()]);
  });

  testWidgets('전투 중(BattleView.bounty): 현상금 띠 + 후퇴 → RetreatBounty, 실패 이벤트 → 창(티켓 반환)', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _state(active: const BountyView(bossId: 'giant_hermit', tier: 2, ticksLeft: 300));
    final log = await _pump(tester, state: s, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    expect(find.byKey(const Key('bounty.strip')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bounty.retreat')));
    await tester.pump();
    expect(log.sent.whereType<RetreatBounty>(), hasLength(1));
    _replace(tester, _state());
    feed.add(
      RecordedTick(s.battle!, const [
        BountyFailed(1, bossId: 'giant_hermit', tier: 2, damageRatio: 0.62, reason: 'retreat'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bounty.result.fail')), findsOneWidget);
    expect(find.text('Ticket returned · 62% damage'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bounty.result.ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bounty.strip')), findsNothing);
  });

  testWidgets('소탕: 깬 단계가 있으면 [소탕 ×N] → SweepBounty, BountySwept → 보상 창', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _state(tickets: 2, cleared: {'giant_hermit': 4});
    final log = await _pump(tester, state: s, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    await _show(tester, 'bounty.sweep');
    expect(find.text('Sweep ×2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bounty.sweep')));
    await tester.pump();
    expect(log.sent.whereType<SweepBounty>().map((c) => c.toJson()), [const SweepBounty('giant_hermit', 2).toJson()]);
    feed.add(
      RecordedTick(s.battle!, const [
        BountySwept(
          1,
          bossId: 'giant_hermit',
          tier: 4,
          count: 2,
          reward: BountyReward(type: 'gems', amount: 26),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bounty.result.clear')), findsOneWidget);
    expect(find.text('26 gems'), findsOneWidget);
  });

  testWidgets('티켓 0: 광고로 1장(AdPlacement.bountyTicket) · 오늘 받았으면 없음', (tester) async {
    await _pump(
      tester,
      state: _state(tickets: 0),
      overrides: [adOfferProvider.overrideWith((ref, p) => p == AdPlacement.bountyTicket)],
    );
    await _show(tester, 'bounty.card');
    expect(find.text('No tickets — 3 more every day'), findsOneWidget);
    // 광고 장치(ads.json bountyTicket)가 표에 있을 때만 버튼 — 아직 없으면 숨긴다(경제 canWatchAd가 실패하므로).
    final hasPlacement = GameTables.load().ads.placements.any((d) => d.id == 'bountyTicket');
    expect(find.byKey(const Key('bounty.ad')), hasPlacement ? findsOneWidget : findsNothing);
    _replace(tester, _state(tickets: 0, adOn: '2026-10-12'));
    await tester.pump();
    expect(find.byKey(const Key('bounty.ad')), findsNothing);
  });

  testWidgets('빨간 점: 티켓 9장일 때만 항해 아이콘에', (tester) async {
    await _pump(tester, state: _state(tickets: 8));
    // 열린 패널 아이콘에는 점을 안 띄우므로 시트를 닫고 본다.
    await tester.tap(find.byKey(const Key('tab.0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tab.dot.0')), findsNothing);
    _replace(tester, _state(tickets: 9));
    await tester.pump();
    expect(find.byKey(const Key('tab.dot.0')), findsOneWidget);
  });

  testWidgets('시트: 요일 7칸(폰 4+3), 화요일 보스는 월요일에 닫힘, 단계 − / +', (tester) async {
    await _pump(tester, state: _state(cleared: {'giant_hermit': 2}));
    await _show(tester, 'bounty.card');
    await tester.tap(find.byKey(const Key('bounty.card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bounty.sheet')), findsOneWidget);
    final d1 = tester.getRect(find.byKey(const Key('bounty.day.1'))).top;
    expect(tester.getRect(find.byKey(const Key('bounty.day.4'))).top, d1);
    expect(tester.getRect(find.byKey(const Key('bounty.day.5'))).top, greaterThan(d1));
    expect(find.text('Tier 3'), findsOneWidget); // 열린 단계 = 깬 2 + 1
    await _show(tester, 'bounty.tier.minus');
    await tester.tap(find.byKey(const Key('bounty.tier.minus')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('bounty.tier'))).data, 'Tier 2');
    await _show(tester, 'bounty.day.2');
    await tester.tap(find.byKey(const Key('bounty.day.2')));
    await tester.pump();
    expect(find.text('Another boss today'), findsOneWidget);
  });

  testWidgets('태블릿: 요일 7칸 한 줄', (tester) async {
    await _pump(tester, size: const Size(800, 1280));
    await _show(tester, 'bounty.card');
    await tester.tap(find.byKey(const Key('bounty.card')));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('bounty.day.7'))).top,
      tester.getRect(find.byKey(const Key('bounty.day.1'))).top,
    );
  });

  testWidgets('일요일: 카드는 특정 보스를 고르지 않음 · 도전 = 시트에서 아무 보스나', (tester) async {
    final log = await _pump(tester, day: 18, state: _state(cleared: {'giant_hermit': 5}));
    await _show(tester, 'bounty.card');
    expect(find.text('All bounty bosses today'), findsOneWidget);
    expect(find.byKey(const Key('bounty.sweep')), findsNothing);
    await tester.tap(find.byKey(const Key('bounty.challenge')));
    await tester.pumpAndSettle();
    expect(find.text('Sunday — any boss'), findsOneWidget);
    await _show(tester, 'bounty.day.2');
    await tester.tap(find.byKey(const Key('bounty.day.2')));
    await tester.pump();
    expect(find.text('Another boss today'), findsNothing);
    await _show(tester, 'bounty.sheet.challenge');
    await tester.tap(find.byKey(const Key('bounty.sheet.challenge')));
    await tester.pumpAndSettle();
    expect(log.sent.whereType<StartBounty>().map((c) => c.toJson()), [const StartBounty('thunder_ray', 1).toJson()]);
  });

  testWidgets('360dp: 카드·시트 넘침 없음', (tester) async {
    await _pump(
      tester,
      size: const Size(360, 1100),
      state: _state(tickets: 9, cleared: {'giant_hermit': 12}),
    );
    await _show(tester, 'bounty.card');
    await tester.tap(find.byKey(const Key('bounty.card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bounty.sheet')), findsOneWidget);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);

    for (final lang in ['ko', 'en']) {
      testWidgets('카드·시트 $lang', (tester) async {
        await _pump(
          tester,
          locale: Locale(lang),
          size: s24Size,
          state: _state(tickets: 9, cleared: {'giant_hermit': 4, 'thunder_ray': 2}, progress: {'giant_hermit': 0.62}),
        );
        await precacheImages(tester);
        await _show(tester, 'bounty.card');
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/${lang}_bounty_card.png'));
        await tester.tap(find.byKey(const Key('bounty.card')));
        await tester.pumpAndSettle();
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/${lang}_bounty_sheet.png'));
      });
    }
  });
}

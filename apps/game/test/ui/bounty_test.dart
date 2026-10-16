import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/bounty/bounty_vm.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';

import 'ui_harness.dart';

// 현상금 사냥 B4 UI (요청서 platform-bounty-b4 · 기획 8절 9). 계약 B0 전이라 가짜 컨트롤러(bountyProvider)로.

/// 2026-10-12 = 월요일(거대 소라게), 10-18 = 일요일.
FixedClock _on(int day) => FixedClock(DateTime(2026, 10, day, 12));

/// 항해 탭이 길어 현상금 카드가 첫 화면 아래에 있을 수 있다 → 세로로 긴 화면.
const _tall = Size(400, 1300);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  int day = 12,
  BountyVm vm = const BountyVm(),
  Size? size,
  Locale? locale,
}) async {
  await pumpGame(
    tester,
    loadFixture('stage37_midgame'),
    clock: _on(day),
    size: size ?? _tall,
    locale: locale ?? const Locale('en'),
  );
  final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  c.read(bountyProvider.notifier).load(vm);
  await tester.pump();
  return c;
}

Future<void> _show(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
}

void main() {
  testWidgets('카드: 월요일 = 거대 소라게·젬 보상·티켓 3/9, 도전 → 현상금 띠·후퇴 → 실패 창(티켓 반환)', (tester) async {
    final c = await _pump(tester);
    await _show(tester, 'bounty.card');
    expect(find.text('Tickets 3/9'), findsOneWidget);
    expect(find.text('10 gems'), findsOneWidget);
    expect(find.byKey(const Key('bounty.sweep')), findsNothing); // 아직 깬 단계 없음
    await tester.tap(find.byKey(const Key('bounty.challenge')));
    await tester.pump();
    expect(c.read(bountyProvider).tickets, 2);
    expect(find.byKey(const Key('bounty.strip')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bounty.retreat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bounty.result.fail')), findsOneWidget);
    expect(find.textContaining('Ticket returned'), findsOneWidget);
    expect(c.read(bountyProvider).tickets, 3);
    await tester.tap(find.byKey(const Key('bounty.result.ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bounty.strip')), findsNothing);
  });

  testWidgets('소탕: 깬 단계가 있으면 [소탕 ×N] → 보상 창', (tester) async {
    await _pump(tester, vm: const BountyVm(tickets: 2, cleared: {'giant_hermit': 4}));
    await _show(tester, 'bounty.sweep');
    expect(find.text('Sweep ×2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bounty.sweep')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bounty.result.clear')), findsOneWidget);
    expect(find.text('26 gems'), findsOneWidget); // floor(10 + 1×3) × 2
  });

  testWidgets('티켓 0: 광고로 1장 (오늘 안 봤을 때만)', (tester) async {
    final c = await _pump(tester, vm: const BountyVm(tickets: 0));
    await _show(tester, 'bounty.ad');
    await tester.tap(find.byKey(const Key('bounty.ad')));
    await tester.pump();
    expect(c.read(bountyProvider).tickets, 1);
    c.read(bountyProvider.notifier).load(const BountyVm(tickets: 0, adUsedToday: true));
    await tester.pump();
    expect(find.byKey(const Key('bounty.ad')), findsNothing);
  });

  testWidgets('빨간 점: 티켓 9장일 때만 항해 아이콘에', (tester) async {
    await _pump(tester, vm: const BountyVm(tickets: 8));
    // 시트가 열려 항해 아이콘은 시트 안 도크에 — 열린 패널에는 점을 안 띄우므로 닫고 본다.
    await tester.tap(find.byKey(const Key('tab.0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tab.dot.0')), findsNothing);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    c.read(bountyProvider.notifier).load(const BountyVm(tickets: 9));
    await tester.pump();
    expect(find.byKey(const Key('tab.dot.0')), findsOneWidget);
  });

  testWidgets('시트: 요일 7칸(폰 4+3), 화요일 보스는 월요일에 닫힘, 단계 − / +', (tester) async {
    await _pump(tester, vm: const BountyVm(cleared: {'giant_hermit': 2}));
    await _show(tester, 'bounty.card');
    await tester.tap(find.byKey(const Key('bounty.card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bounty.sheet')), findsOneWidget);
    // 폰: 1~4일이 같은 줄, 5일은 다음 줄.
    expect(
      tester.getRect(find.byKey(const Key('bounty.day.4'))).top,
      tester.getRect(find.byKey(const Key('bounty.day.1'))).top,
    );
    expect(
      tester.getRect(find.byKey(const Key('bounty.day.5'))).top,
      greaterThan(tester.getRect(find.byKey(const Key('bounty.day.1'))).top),
    );
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

  testWidgets('일요일: 아무 보스나 도전 가능', (tester) async {
    await _pump(tester, day: 18);
    await _show(tester, 'bounty.card');
    await tester.tap(find.byKey(const Key('bounty.card')));
    await tester.pumpAndSettle();
    expect(find.text('Sunday — any boss'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bounty.day.2')));
    await tester.pump();
    expect(find.text('Challenge'), findsWidgets);
    expect(find.text('Another boss today'), findsNothing);
  });

  testWidgets('360dp: 카드·시트 넘침 없음', (tester) async {
    await _pump(
      tester,
      size: const Size(360, 1100),
      vm: const BountyVm(tickets: 9, cleared: {'giant_hermit': 12}),
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
          vm: const BountyVm(
            tickets: 9,
            cleared: {'giant_hermit': 4, 'thunder_ray': 2},
            progress: {'giant_hermit': 0.62},
          ),
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

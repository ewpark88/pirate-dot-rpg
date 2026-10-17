import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/meta/trial_gate.dart';
import 'package:pirate_dot/ui/pixel/pixel_ring.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

GameState _withChest({int ticksLeft = 400}) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    battle: s.battle!.copyWith(chest: ChestView(x: 150, y: 200, ticksLeft: ticksLeft), shipX: 135, shipY: 240),
  );
}

void main() {
  testWidgets('기준 2: 상자가 떠 있으면 탭 영역, 누르면 TapChest', (tester) async {
    final log = await pumpGame(tester, _withChest());
    expect(find.byKey(const Key('chest')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chest')));
    expect(log.sent, [isA<TapChest>()]);
  });

  testWidgets('기준 2: 상자가 없으면 탭 영역 없음', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.byKey(const Key('chest')), findsNothing);
  });

  testWidgets('상자는 탑다운 전장 좌표 (150, 200) → 렌더와 같은 topFrameFor.worldToDp 자리(배 중심 기준)', (tester) async {
    await pumpGame(tester, _withChest(), openTab: false);
    final battle = tester.getRect(find.byKey(const Key('battle.area')));
    final at =
        battle.topLeft + topFrameFor(battle.size, s24Dpr).worldToDp(const Offset(150, 200), const Offset(135, 240));
    expect(tester.getCenter(find.byKey(const Key('chest'))), offsetMoreOrLessEquals(at, epsilon: 0.5));
  });

  testWidgets('피버 중 배가 좌우로 움직여도(shipX ±60) 상자 자리는 카메라 기준(waves.top.shipX) — 렌더와 같다', (tester) async {
    final base = _withChest();
    final moved = base.copyWith(battle: base.battle!.copyWith(shipX: 195));
    await pumpGame(tester, moved, openTab: false);
    final battle = tester.getRect(find.byKey(const Key('battle.area')));
    final camX = GameTables.load().waves.top.shipX;
    final at = battle.topLeft + topFrameFor(battle.size, s24Dpr).worldToDp(const Offset(150, 200), Offset(camX, 240));
    expect(tester.getCenter(find.byKey(const Key('chest'))), offsetMoreOrLessEquals(at, epsilon: 0.5));
  });

  testWidgets('가라앉기까지 남은 시간 링 = ticksLeft / (floatSec × 1000 / tickMs)', (tester) async {
    await pumpGame(tester, _withChest(ticksLeft: 200)); // 40초 × 20틱 = 800틱 중 200
    final ring = tester.widget<PixelRing>(
      find.descendant(of: find.byKey(const Key('chest')), matching: find.byType(PixelRing)),
    );
    expect(ring.value, closeTo(0.25, 1e-9));
  });

  testWidgets('기준 3: 광고 포트가 없으면 상자 광고 버튼 없음', (tester) async {
    await pumpGame(tester, _withChest());
    expect(find.byKey(const Key('chest.ad')), findsNothing);
  });

  testWidgets('보상 미리보기가 있으면 상자 위에 금액 (경제 B3 전엔 없음)', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = _withChest();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trialsEnabledProvider.overrideWithValue(false),
          initialGameStateProvider.overrideWithValue(state),
          battleViewBuilderProvider.overrideWithValue((_) => const SizedBox()),
          clockProvider.overrideWithValue(FixedClock(state.savedAt)),
          chestRewardProvider.overrideWithValue((_) => BigNum.parse('2.5e5')),
        ],
        child: const PirateDotApp(locale: Locale('en')),
      ),
    );
    await tester.pump();
    expect(find.descendant(of: find.byKey(const Key('chest')), matching: find.text('250K')), findsOneWidget);
  });

  // 사용자 지시 2026-10-16 말풍선 삭제 → 2026-10-17 '왼쪽 아이콘도 띄우지 마라, 상자를 누르면 창만'.
  testWidgets('광고 준비: 알약 없음 · 상자를 누르면 작은 창(그냥 받기 · 광고 ×n 골드 · 광고 젬) → TapChest', (tester) async {
    final log = await pumpGame(
      tester,
      _withChest(),
      openTab: false,
      overrides: [adOfferProvider.overrideWith((ref, _) => true)],
    );
    expect(find.byKey(const Key('chest.adBubble')), findsNothing);
    expect(find.byKey(const Key('chest.pill')), findsNothing);
    await tester.tap(find.byKey(const Key('chest')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chest.sheet')), findsOneWidget);
    expect(find.textContaining('Ad ×'), findsOneWidget); // 광고 쪽 이득 표시
    // 작게: 폰 폭 85% 이하.
    // 창 판 폭(리본이 판 전체 폭) = 폰 폭 85% 이하(팝업 기준).
    expect(tester.getSize(find.byKey(const Key('dialog.ribbon'))).width, lessThanOrEqualTo(384 * 0.85));
    expect(find.byKey(const Key('ad.chest.gold')), findsOneWidget);
    expect(find.byKey(const Key('ad.chest.gems')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chest.take')));
    await tester.pumpAndSettle();
    expect(log.sent, [isA<TapChest>()]);
    expect(find.byKey(const Key('chest.sheet')), findsNothing);
  });

  testWidgets('광고 준비: 상자를 눌러도 같은 시트 · 상자가 가라앉으면 시트가 닫힌다', (tester) async {
    await pumpGame(
      tester,
      _withChest(),
      openTab: false,
      overrides: [adOfferProvider.overrideWith((ref, _) => true)],
    );
    await tester.tap(find.byKey(const Key('chest')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chest.sheet')), findsOneWidget);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    c.read(gameStateProvider.notifier).replace(loadFixture('stage37_midgame'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chest.sheet')), findsNothing);
    expect(find.byKey(const Key('chest.pill')), findsNothing);
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);

    for (final (name, size, dpr) in [
      ('360', const Size(360, 640), 3.0),
      ('s24', s24Size, s24Dpr),
      ('411', const Size(411, 891), 2.625),
      ('tablet', const Size(800, 1280), 2.0),
    ]) {
      testWidgets('상자 선택 창 $name', (tester) async {
        await pumpGame(
          tester,
          _withChest(),
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
          openTab: false,
          overrides: [adOfferProvider.overrideWith((ref, _) => true)],
        );
        await precacheImages(tester);
        await tester.tap(find.byKey(const Key('chest')));
        await tester.pumpAndSettle();
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_chest_choice_$name.png'));
      });
    }
  });

  testWidgets('처음 3번: 상자 위 톡! + MarkHint(chest.tap1) · 3번 다 봤으면 없음 (#6)', (tester) async {
    // guides: true = 본 기록이 빈 샘플 그대로.
    final log = await pumpGame(tester, _withChest(), openTab: false, guides: true);
    await tester.pump();
    expect(find.byKey(const Key('chest.tapHint')), findsOneWidget);
    expect(log.hints.map((c) => c.id), contains('chest.tap1'));
    await tester.pump(const Duration(seconds: 2));
    // 기본 하네스는 chest.tap1~3을 본 것으로 둔다.
    await pumpGame(tester, _withChest(), openTab: false);
    await tester.pump();
    expect(find.byKey(const Key('chest.tapHint')), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
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
}

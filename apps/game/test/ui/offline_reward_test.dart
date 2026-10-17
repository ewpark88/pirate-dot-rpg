import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart' show guidesEnabledProvider;
import 'package:pirate_dot/ui/meta/trial_gate.dart';
import 'package:pirate_dot/ui/offline/offline_reward.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

/// S2의 offlinePreview가 오기 전 가짜: 경과를 0~8시간으로 자르고, 1분 미만이면 없음. 골드는 초당 100.
OfflinePreview? _fakePreview(GameState s, DateTime now) {
  final seconds = math.min(now.difference(s.savedAt).inSeconds, const Duration(hours: 8).inSeconds);
  if (seconds < Duration.secondsPerMinute) return null;
  return OfflinePreview(seconds: seconds, gold: BigNum.from(seconds * 100), cards: 2);
}

Future<CommandLog> _pump(WidgetTester tester, Duration away, {bool fake = true}) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = _roomy();
  final log = CommandLog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trialsEnabledProvider.overrideWithValue(false),
        guidesEnabledProvider.overrideWithValue(false), // 처음 만나는 안내(업적 등)가 끼지 않게
        initialGameStateProvider.overrideWithValue(state),
        commandSinkProvider.overrideWithValue(log),
        battleViewBuilderProvider.overrideWithValue((_) => const ColoredBox(color: Colors.blueGrey)),
        clockProvider.overrideWithValue(FixedClock(state.savedAt.add(away))),
        if (fake) offlinePreviewProvider.overrideWithValue(_fakePreview),
      ],
      child: const PirateDotApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
  return log;
}

/// 화물칸에 넉넉한 여유(복귀 골드가 잘리지 않게 — 잘림은 cargo_test).
GameState _roomy() => withCargoRoom(loadFixture('stage37_midgame'), extra: BigNum.parse('1e40'));

void main() {
  testWidgets('기준 3: 2시간 뒤 시작 → 팝업 1개, 받기 → ClaimOffline, 닫힘', (tester) async {
    final log = await _pump(tester, const Duration(hours: 2));
    expect(find.byType(OfflineRewardDialog), findsOneWidget);
    expect(find.text('While you were away: 2h 0m'), findsOneWidget);
    expect(find.text(BigNum.from(7200 * 100).format()), findsOneWidget);
    expect(find.text('Cards 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('offline.claim')));
    await tester.pumpAndSettle();
    expect(log.sent, [isA<ClaimOffline>()]);
    expect(find.byType(OfflineRewardDialog), findsNothing);
  });

  testWidgets('기준 4: 최소 시간 미만이면 팝업 없음', (tester) async {
    await _pump(tester, const Duration(seconds: 30));
    expect(find.byType(OfflineRewardDialog), findsNothing);
  });

  testWidgets('기준 5: 팝업이 떠 있을 때 복귀가 또 와도 1개', (tester) async {
    await _pump(tester, const Duration(hours: 2));
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(OfflineRewardDialog), findsOneWidget);
  });

  testWidgets('기준 5: 같은 복귀는 한 번 · 받은 뒤 새로 떠났다 오면 새 팝업', (tester) async {
    await _pump(tester, const Duration(hours: 2));
    await tester.tap(find.byKey(const Key('offline.claim')));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(PirateDotApp)));
    final s = c.read(gameStateProvider);
    // 같은 복귀(savedAt 그대로)로는 다시 안 뜬다(실기기 ① 중복).
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(OfflineRewardDialog), findsNothing);
    // 엔진이 받기를 처리해 savedAt이 바뀐 뒤 다시 오래 떠났다 오면 새 팝업(테스트엔 엔진이 없어 직접 바꾼다).
    c.read(gameStateProvider.notifier).replace(s.copyWith(savedAt: s.savedAt.subtract(const Duration(hours: 1))));
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(OfflineRewardDialog), findsOneWidget);
  });

  testWidgets('기준 6: 20시간이어도 표시는 8시간 (미리보기 결과 그대로)', (tester) async {
    await _pump(tester, const Duration(hours: 20));
    expect(find.text('While you were away: 8h 0m'), findsOneWidget);
  });

  testWidgets('바깥을 눌러도 닫히지 않는다 (받기만)', (tester) async {
    await _pump(tester, const Duration(hours: 2));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(OfflineRewardDialog), findsOneWidget);
  });

  testWidgets('실제 경제 함수: 2시간 뒤 미리보기 골드를 그대로 보인다', (tester) async {
    await _pump(tester, const Duration(hours: 2), fake: false);
    final state = _roomy();
    final expected = offlinePreview(state, GameTables.load(), state.savedAt.add(const Duration(hours: 2)))!;
    expect(find.byType(OfflineRewardDialog), findsOneWidget);
    expect(find.text(expected.gold.format()), findsOneWidget);
  });

  testWidgets('경제 기본값: 5분 미만 부재면 복귀 창이 뜨지 않는다 (minSec 300)', (tester) async {
    await _pump(tester, const Duration(minutes: 4), fake: false);
    expect(find.byType(OfflineRewardDialog), findsNothing);
  });

  testWidgets('경제 기본값: 10분 부재면 복귀 창이 뜬다', (tester) async {
    await _pump(tester, const Duration(minutes: 10), fake: false);
    expect(find.byType(OfflineRewardDialog), findsOneWidget);
  });
}

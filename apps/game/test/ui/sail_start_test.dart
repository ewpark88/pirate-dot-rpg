import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 환생 뒤 출항 (사용자 피드백 #19): 상자 창 '출항!' 또는 전장 가운데 '출항!' → StartVoyage.

void main() {
  GameState held({bool hold = true}) {
    final s = loadFixture('stage37_midgame');
    return s.copyWith(progress: s.progress.copyWith(rebirths: 1, sailHold: hold));
  }

  testWidgets('출항 대기면 전장 가운데 큰 출항 버튼(56dp) → StartVoyage', (tester) async {
    final log = await pumpGame(tester, held(), openTab: false);
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('sail.start'));
    expect(button, findsOneWidget);
    expect(find.byKey(const Key('sail.hint')), findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(56));
    await tester.tap(button);
    expect(log.sent.whereType<StartVoyage>(), hasLength(1));
  });

  testWidgets('대기가 아니면 출항 버튼 없음', (tester) async {
    await pumpGame(tester, held(hold: false), openTab: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sail.start')), findsNothing);
  });

  testWidgets('환생 상자 창: 열고 출항! → StartVoyage 한 번 + 창 닫힘(창이 떠 있는 동안 전장 출항 버튼은 숨김)', (tester) async {
    final state = held(hold: false).copyWith(clearTutorial: true);
    final log = await pumpGame(tester, state, openTab: false);
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    container
        .read(gameStateProvider.notifier)
        .replace(state.copyWith(progress: state.progress.copyWith(rebirths: 2, sailHold: true)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rebirth.chest')), findsOneWidget);
    expect(find.byKey(const Key('sail.start')), findsNothing);
    await tester.tap(find.byKey(const Key('rebirth.chest.open')));
    await tester.pumpAndSettle();
    expect(find.text('Set sail!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rebirth.chest.sail')));
    await tester.pumpAndSettle();
    expect(log.sent.whereType<StartVoyage>(), hasLength(1));
    expect(find.byKey(const Key('rebirth.chest')), findsNothing);
  });

  testWidgets('골든: 출항 대기 s24 ko', (tester) async {
    await loadGoldenFonts();
    await pumpGame(tester, held(), locale: const Locale('ko'), openTab: false);
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_sail_start_s24.png'));
  });
}

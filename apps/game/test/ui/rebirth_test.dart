import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

const _available = RebirthPreview(
  locked: false,
  minStage: 40,
  currentPieces: 0,
  gain: 7,
  nextPieceInStages: 3,
  bonusPerPiece: 0.05,
);

const _locked = RebirthPreview(
  locked: true,
  minStage: 40,
  currentPieces: 0,
  gain: 0,
  nextPieceInStages: 0,
  bonusPerPiece: 0.05,
);

/// 항해 탭이 길어 환생 카드가 첫 화면 아래에 있다 → 세로로 긴 화면.
const _tall = Size(400, 1100);

/// 특정 화면 상태를 만들려고 provider를 가짜로 덮는다. 항해 탭(0)이 기본.
Future<CommandLog> _pump(WidgetTester tester, RebirthPreview? preview, {GameState? state}) async {
  tester.view
    ..physicalSize = _tall
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = state ?? loadFixture('stage37_midgame');
  final log = CommandLog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(s),
        commandSinkProvider.overrideWithValue(log),
        battleViewBuilderProvider.overrideWithValue((_) => const SizedBox()),
        clockProvider.overrideWithValue(FixedClock(s.savedAt)),
        rebirthPreviewProvider.overrideWithValue((_) => preview),
      ],
      child: const PirateDotApp(locale: Locale('en')),
    ),
  );
  await tester.pump();
  return log;
}

void main() {
  testWidgets('기준 1: 가능 — 조각 +7, 다음 조각까지 3, 보물지도 버튼', (tester) async {
    await _pump(tester, _available);
    expect(find.text('Rebirth now: +7 pieces'), findsOneWidget);
    expect(find.text('Next piece in 3 stages'), findsOneWidget);
    expect(find.text('Map pieces 0 · Damage·Gold +0%'), findsOneWidget);
    expect(find.byKey(const Key('rebirth.open')), findsOneWidget);
  });

  testWidgets('기준 2: 불가(이번 회차 스테이지 37) — 버튼 없음, 해금 문구와 막대 37/40', (tester) async {
    await _pump(tester, _locked);
    expect(find.byKey(const Key('rebirth.open')), findsNothing);
    expect(find.text('Rebirth unlocks at stage 40'), findsOneWidget);
    final bar = tester.widget<PixelBar>(
      find.descendant(of: find.byKey(const Key('rebirth.card')), matching: find.byType(PixelBar)),
    );
    expect(bar.value, closeTo(37 / 40, 1e-9));
  });

  testWidgets('기준 3: 확인 창 3줄 → 펼치기 → Rebirth', (tester) async {
    final log = await _pump(tester, _available);
    await tester.ensureVisible(find.byKey(const Key('rebirth.open')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rebirth.open')));
    await tester.pumpAndSettle();
    expect(find.text('Reset: stage, gold, ship upgrades'), findsOneWidget);
    expect(find.text('Kept: crew, collection, gems'), findsOneWidget);
    expect(find.text('Gain: +7 pieces, bonus +0% to +35%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rebirth.confirm')));
    await tester.pumpAndSettle();
    expect(log.sent, [isA<Rebirth>()]);
  });

  testWidgets('기준 3: 취소 → 명령 없음', (tester) async {
    final log = await _pump(tester, _available);
    await tester.ensureVisible(find.byKey(const Key('rebirth.open')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rebirth.open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rebirth.cancel')));
    await tester.pumpAndSettle();
    expect(log.sent, isEmpty);
  });

  testWidgets('기본값은 경제 rebirthPreview — 샘플(스테이지 37)은 잠김, 최고 스테이지 표시', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), size: _tall);
    expect(find.byKey(const Key('rebirth.card')), findsOneWidget);
    expect(find.text('Rebirth unlocks at stage 40'), findsOneWidget);
    expect(find.text('Best stage 41'), findsOneWidget);
  });

  testWidgets('환생 결과 팝업: 환생 횟수가 늘면 그 사이 늘어난 조각 +7', (tester) async {
    final state = loadFixture('stage37_midgame').copyWith(clearTutorial: true);
    await pumpGame(tester, state);
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    container
        .read(gameStateProvider.notifier)
        .replace(
          state.copyWith(
            progress: state.progress.copyWith(rebirths: state.progress.rebirths + 1),
            wallet: state.wallet.copyWith(mapPieces: state.wallet.mapPieces + 7),
          ),
        );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rebirth.done')), findsOneWidget);
    expect(find.textContaining('+7 map pieces'), findsOneWidget);
  });
}

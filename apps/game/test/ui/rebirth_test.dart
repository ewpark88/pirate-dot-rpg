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
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';

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
  // 도크 + 시트: 항해 패널을 연다.
  await tester.tap(find.byKey(const Key('tab.0')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await _scrollToCard(tester);
  return log;
}

/// 환생 카드는 항해 탭 아래쪽(아직 안 지어졌을 수 있음) — 스크롤해서 짓는다.
Future<void> _scrollToCard(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('rebirth.card')),
    200,
    scrollable: find.descendant(of: find.byType(VoyageTab), matching: find.byType(Scrollable)).first,
  );
  await tester.pump();
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
    // 설명 판(rebirth.why): 얻는 것 / 잃는 것 / 그대로 (사용자 지시 2026-10-16).
    expect(find.text('Stage · ship part levels · gold'), findsOneWidget);
    expect(find.text('Crew · collection · gems · ship look'), findsOneWidget);
    expect(find.text('Map pieces +7'), findsOneWidget);
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
    // 최고 스테이지는 맨 위 해역 카드 — 아래 카드로 스크롤하기 전에 본다.
    expect(find.text('Best stage 41'), findsOneWidget);
    await _scrollToCard(tester);
    expect(find.byKey(const Key('rebirth.card')), findsOneWidget);
    expect(find.text('Rebirth unlocks at stage 40'), findsOneWidget);
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
    // 환생 v2: 상자 팝업 → 열기 → 조각 줄이 튀어나온다.
    expect(find.byKey(const Key('rebirth.chest')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rebirth.chest.open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('+7 map pieces'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rebirth.chest.sail')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rebirth.chest')), findsNothing);
  });
}

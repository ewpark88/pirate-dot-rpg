import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

const _available = RebirthPreviewView(
  unlockStage: 40,
  available: true,
  currentPieces: 0,
  gainPieces: 7,
  nextPieceInStages: 3,
  bonusPerPiece: 0.05,
);

const _locked = RebirthPreviewView(
  unlockStage: 40,
  available: false,
  currentPieces: 0,
  gainPieces: 0,
  nextPieceInStages: 0,
  bonusPerPiece: 0.05,
);

/// S2 환생 미리보기 함수가 오기 전이라 provider를 가짜로 덮는다. 항해 탭(0)이 기본.
Future<CommandLog> _pump(WidgetTester tester, RebirthPreviewView? preview, {GameState? state}) async {
  tester.view
    ..physicalSize = const Size(400, 800)
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

  testWidgets('기준 2: 불가(최고 37) — 버튼 없음, 해금 문구와 막대 37/40', (tester) async {
    final base = loadFixture('stage37_midgame');
    await _pump(tester, _locked, state: base.copyWith(progress: base.progress.copyWith(bestStage: 37)));
    expect(find.byKey(const Key('rebirth.open')), findsNothing);
    expect(find.text('Rebirth unlocks at stage 40'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.descendant(of: find.byKey(const Key('rebirth.card')), matching: find.byType(LinearProgressIndicator)),
    );
    expect(bar.value, closeTo(37 / 40, 1e-9));
  });

  testWidgets('기준 3: 확인 창 3줄 → 펼치기 → Rebirth', (tester) async {
    final log = await _pump(tester, _available);
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
    await tester.tap(find.byKey(const Key('rebirth.open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rebirth.cancel')));
    await tester.pumpAndSettle();
    expect(log.sent, isEmpty);
  });

  testWidgets('미리보기 없음(S2 함수 전 기본값)이면 카드 없음, 항해 탭에 최고 스테이지', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.byKey(const Key('rebirth.card')), findsNothing);
    expect(find.text('Best stage 41'), findsOneWidget);
  });
}

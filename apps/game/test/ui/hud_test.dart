import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'ui_harness.dart';

void main() {
  testWidgets('기준 1: 골드·젬·스테이지', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.text('1.25M'), findsOneWidget);
    expect(find.text('140'), findsOneWidget);
    expect(find.text('Stage 37-2'), findsOneWidget);
  });

  testWidgets('기준 1 (ko): 스테이지 문구', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), locale: const Locale('ko'));
    expect(find.text('스테이지 37-2'), findsOneWidget);
  });

  testWidgets('기준 2: 보스전이면 남은 초 (400틱 × 50ms = 20초)', (tester) async {
    await pumpGame(tester, loadFixture('boss_fight'));
    expect(find.text('Boss 20s'), findsOneWidget);
  });

  testWidgets('기준 2: 보스전이 아니면 타이머가 없다', (tester) async {
    await pumpGame(tester, loadFixture('new_player'));
    expect(find.textContaining('Boss'), findsNothing);
  });

  testWidgets('기준 3: 함성이 덜 찼으면 궁극기 버튼 비활성', (tester) async {
    final log = await pumpGame(tester, loadFixture('stage37_midgame'));
    await tester.tap(find.byKey(const Key('hud.ultimate')));
    expect(log.sent, isEmpty);
  });

  testWidgets('기준 3: 함성이 가득이면 누를 때 TriggerUltimate 1개', (tester) async {
    final base = loadFixture('stage37_midgame');
    final full = base.copyWith(progress: base.progress.copyWith(rage: 1));
    final log = await pumpGame(tester, full);
    await tester.tap(find.byKey(const Key('hud.ultimate')));
    expect(log.sent, [isA<TriggerUltimate>()]);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'ui_harness.dart';

GameState _farming(String fixture) {
  final s = loadFixture(fixture);
  return s.copyWith(progress: s.progress.copyWith(farming: true));
}

void main() {
  testWidgets('기준 1: 파밍 중이면 선원 줄 보스 칸에 보스 도전 → ChallengeBoss', (tester) async {
    final log = await pumpGame(tester, _farming('stage37_midgame'));
    expect(find.byTooltip('Challenge Boss'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boss.challenge')));
    expect(log.sent, [isA<ChallengeBoss>()]);
  });

  testWidgets('기준 2: 파밍이 아니면 버튼이 없다', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.byKey(const Key('boss.challenge')), findsNothing);
  });

  testWidgets('기준 2: 보스전 중이면 파밍 표시여도 버튼이 없다', (tester) async {
    await pumpGame(tester, _farming('boss_fight'));
    expect(find.byKey(const Key('boss.challenge')), findsNothing);
  });
}

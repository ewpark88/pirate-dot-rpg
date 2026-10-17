import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

import 'ui_harness.dart';

// 도감 수집 보상 '보상 받기' (S1 2026-10-17): 선원 탭 도감 카드 아래 — 받을 칸이 있으면 금빛 버튼, 없으면 다음 칸 안내.

GameState _with(GameState s, int owned, {List<int> claimed = const []}) {
  final ids = GameTables.load().crews.crews.take(owned).map((c) => c.id).toSet();
  return s.copyWith(
    collection: ids,
    progress: s.progress.copyWith(collectionClaimed: claimed),
  );
}

void main() {
  testWidgets('6명 · 5명 칸 안 받음 → [보상 받기 (5명)] → ClaimCollectionReward(5)', (tester) async {
    final log = await pumpGame(tester, _with(loadFixture('stage37_midgame'), 6), tab: crewTab);
    await tester.tap(find.byKey(const Key('collect.claim')));
    await tester.pump();
    expect(log.sent.whereType<ClaimCollectionReward>().single.at, 5);
  });

  testWidgets('6명 · 5명 칸 받음 → 버튼 없이 다음 칸 안내(10명: 무료 소환 1회)', (tester) async {
    await pumpGame(
      tester,
      _with(loadFixture('stage37_midgame'), 6, claimed: [5]),
      tab: crewTab,
      locale: const Locale('en'),
    );
    expect(find.byKey(const Key('collect.claim')), findsNothing);
    expect(find.text('Next reward at 10: Free summon ×1'), findsOneWidget);
  });
}

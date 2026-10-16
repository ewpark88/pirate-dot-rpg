import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';

import 'ui_harness.dart';

void main() {
  final tables = GameTables.load();

  testWidgets('기준 1: 해역 카드 — Coral Reef 37/50, 해역 보스까지 13, 보스 이름·약점, 다음 해역', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    final region = find.byKey(const Key('voyage.region'));
    expect(find.descendant(of: region, matching: find.textContaining('Coral Reef')), findsOneWidget);
    expect(find.descendant(of: region, matching: find.text('37/50')), findsOneWidget);
    expect(find.text('Region boss in 13 stages'), findsOneWidget);
    expect(find.text('Giant Hermit Crab'), findsOneWidget);
    expect(find.descendant(of: region, matching: find.text('Weak')), findsOneWidget);
    expect(find.text('Next: Storm Sea'), findsOneWidget);
  });

  testWidgets('해역 보스 스테이지(50)면 ‘Region boss stage!’', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s.copyWith(progress: s.progress.copyWith(stage: 50)));
    // 스테이지 50은 환생 가능 → 보물지도 카드가 맨 위라 해역 카드까지 스크롤.
    await tester.scrollUntilVisible(
      find.byKey(const Key('voyage.region')),
      200,
      scrollable: find.descendant(of: find.byType(VoyageTab), matching: find.byType(Scrollable)).first,
    );
    await tester.pump();
    expect(find.text('Region boss stage!'), findsOneWidget);
    expect(find.text('Next: Storm Sea'), findsOneWidget);
  });

  testWidgets('기준 2: 오프라인 시간당 = offlinePreview(savedAt + 1h), 최대 8시간', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s);
    final perHour = offlinePreview(s, tables, s.savedAt.add(const Duration(hours: 1)))!.gold;
    expect(find.text('Offline gold ~${perHour.format()}/h · up to 8h'), findsOneWidget);
  });

  testWidgets('기준 3: 순풍 1:30 ×2 / 없음', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s);
    expect(find.text('Tailwind 1:30 ×2'), findsOneWidget);
    await pumpGame(tester, s.copyWith(buffs: const Buffs()));
    expect(find.text('No tailwind'), findsOneWidget);
  });
}

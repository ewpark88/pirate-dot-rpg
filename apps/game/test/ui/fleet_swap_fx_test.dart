import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

import 'ui_harness.dart';

// 편성 교체 연출 (사용자 2026-10-18): 칸의 출전 선원이 바뀌면 '교체!' · 떨어져 착지 · 금빛 테, 0.7초 뒤 사라짐.
// 자동 편성인데 바뀐 게 없으면 '이미 최강 편성' 토스트.

void main() {
  final t = GameTables.load();

  testWidgets('1번 칸 선원이 바뀌면 교체 연출 → 0.7초 뒤 사라짐', (tester) async {
    final base = loadFixture('stage37_midgame');
    final fleet = activeFleet(base, t);
    final s = base.copyWith(crews: {...base.crews, 'starry': base.crews['octo']!}, fleet: fleet, fleetInit: true);
    await pumpGame(tester, s, openTab: false);
    replaceState(tester, s.copyWith(fleet: [fleet[0], 'starry', ...fleet.skip(2)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('fleet.swapped.1')), findsOneWidget);
    expect(find.byKey(const Key('fleet.swapped.0')), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const Key('fleet.swapped.1')), findsNothing);
  });

  testWidgets('자동 편성인데 바뀐 게 없으면 "이미 최강 편성"', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: 2);
    await tester.tap(find.byKey(const Key('fleet.auto')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Already your strongest fleet'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}

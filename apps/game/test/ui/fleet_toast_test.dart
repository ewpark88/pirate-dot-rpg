import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';

import 'ui_harness.dart';

/// 슬롯 3상태(잠긴 칸 안내)와 편성 거절 안내 (사용자 지시 2026-10-15).
void main() {
  testWidgets('잠긴 칸을 누르면 그 칸이 열리는 배 등급·스테이지 안내', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame')); // 스테이지 37 = 4칸 → 5번째 칸(4)부터 잠김
    expect(find.byKey(const Key('fleet.slot.4')), findsNothing);
    await tester.tap(find.byKey(const Key('fleet.locked.4')));
    await tester.pump();
    expect(find.byKey(const Key('skin.toast')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('skin.toast')), matching: find.textContaining('stage')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('skin.toast')), findsNothing);
  });

  testWidgets('FleetRejected 이벤트가 오면 같은 계열 상한 안내', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final state = loadFixture('stage37_midgame');
    await pumpGame(tester, state, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(RecordedTick(state.battle!, const [FleetRejected(1, slot: 2, crewId: 'manta', reason: 'family')]));
    await tester.pump();
    expect(find.text('Up to 2 crew of the same type can sail together'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

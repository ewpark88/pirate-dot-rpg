import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';

import 'ui_harness.dart';

// 배 부위 강화 손맛 (사용자 2026-10-18): PartUpgraded → 그 줄 '+n%' 떠오름, 5연타면 '연속 강화!'.

void main() {
  testWidgets('대포 강화 → +% 떠오름 · 1초 안 5연타 → 연속 강화!', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('stage37_midgame');
    final lv = s.ship.level('cannon');
    await pumpGame(tester, s, tab: 1, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(RecordedTick(s.battle!, [PartUpgraded(1, part: 'cannon', level: lv + 1)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('ship.gain.cannon')), findsOneWidget);
    for (var i = 2; i <= 5; i++) {
      feed.add(RecordedTick(s.battle!, [PartUpgraded(i, part: 'cannon', level: lv + i)]));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('ship.combo.cannon')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('ship.gain.cannon')), findsNothing);
  });
}

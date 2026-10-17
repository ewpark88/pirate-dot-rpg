import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/state/crash_context.dart';

import 'ui_harness.dart';

// 보고서 맥락 키(S1 2026-10-18): 바뀔 때만 보낸다 — 같은 틱이 이어져도 한 번.

void main() {
  test('적 수 묶음', () {
    expect([0, 3, 10, 99, 500].map(enemyBucket), ['0', '1-9', '10-49', '50-99', '100+']);
  });

  testWidgets('build·thermal은 처음 한 번, scene·fever·enemies는 바뀔 때만', (tester) async {
    final sent = <String>[];
    final feed = StreamController<RecordedTick>.broadcast();
    final s = loadFixture('stage37_midgame');
    await pumpGame(
      tester,
      s,
      openTab: false,
      overrides: [
        battleFeedProvider.overrideWithValue(feed.stream),
        crashKeyProvider.overrideWithValue((k, v) => sent.add('$k=$v')),
      ],
    );
    expect(sent, containsAll(['build=0.1.0+1', 'thermal=none']));
    sent.clear();
    for (var i = 0; i < 5; i++) {
      feed.add(RecordedTick(s.battle!, const []));
      await tester.pump();
    }
    expect(sent.where((e) => e.startsWith('scene=')), ['scene=sea']);
    expect(sent.where((e) => e.startsWith('fever=')).length, 1);
    expect(sent.where((e) => e.startsWith('enemies=')).length, 1);
    await feed.close();
  });
}

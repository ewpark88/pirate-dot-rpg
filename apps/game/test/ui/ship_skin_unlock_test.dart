import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';

import 'ui_harness.dart';

// 배 스킨 칸 (S1 2026-10-17): 새 스킨을 얻으면 토스트 '새 배 스킨: …!' + [입어 보기] → SelectShipSkin.
// 환생 스킨은 환생 보물상자 창이 보여 주니 토스트 없음.

void main() {
  testWidgets('SkinUnlocked(king) → 토스트 + 입어 보기 → SelectShipSkin(king) · 환생 스킨(coral)은 토스트 없음', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('stage37_midgame');
    final owned = s.copyWith(ship: s.ship.copyWith(skinsOwned: {'king'}));
    final log = await pumpGame(
      tester,
      owned,
      openTab: false,
      overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
    );
    feed.add(RecordedTick(owned.battle!, const [SkinUnlocked(3, id: 'coral')]));
    await tester.pump();
    expect(find.byKey(const Key('skin.toast')), findsNothing);
    feed.add(RecordedTick(owned.battle!, const [SkinUnlocked(4, id: 'king')]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('skin.toast')), findsOneWidget);
    await tester.tap(find.byKey(const Key('skin.toast.action')));
    await tester.pump();
    expect(log.sent.whereType<SelectShipSkin>().single.id, 'king');
    await tester.pump(const Duration(seconds: 5));
  });
}

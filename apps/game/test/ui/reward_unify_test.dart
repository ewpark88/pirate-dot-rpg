import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/widgets/reward_burst.dart';

import 'ui_harness.dart';

// 모든 '받기'를 같은 보상 터짐으로 (S1 2026-10-18): 패스 보상 · 일일 퀘스트(이벤트 없이 저장 이유 + 늘어난 젬) ·
// 패스 단계가 오르면 작은 토스트.

void main() {
  testWidgets('패스 보상 받기 → 보상 터짐', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(RecordedTick(s.battle!, const [PassRewardClaimed(1, level: 1, paid: false, gems: 20)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(RewardBurst), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('일일 퀘스트 받기(저장 이유 claimDaily) → 늘어난 젬으로 보상 터짐', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    replaceState(tester, s.copyWith(wallet: s.wallet.copyWith(gems: s.wallet.gems + 10)));
    feed.add(RecordedTick(s.battle!, const [SaveRequested(1, reason: 'claimDaily')]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(RewardBurst), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('패스 단계가 오르면 토스트 "Voyage Pass level 2!"', (tester) async {
    final t = GameTables.load();
    final s = loadFixture('stage37_midgame');
    final at = s.copyWith(
      pass: PassState(season: t.iap.pass.season, xp: t.iap.pass.xpPerLevel, best: 37),
    );
    await pumpGame(tester, at, openTab: false);
    replaceState(
      tester,
      at.copyWith(
        pass: PassState(season: t.iap.pass.season, xp: t.iap.pass.xpPerLevel * 2, best: 37),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Voyage Pass level 2!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}

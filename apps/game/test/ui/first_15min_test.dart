import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/meta/trial_gate.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';

import 'ui_harness.dart';

// 새 게임 첫 15분 UI 흐름 (S1 2026-10-18): 창은 한 번에 하나, 창이 떠 있으면 옥토 말풍선은 숨는다.
// 첫 보스 실패 → 실패 안내(판) · 옥토 '다시 도전' 말풍선 → 조용한 45초 뒤 맛보기(자동 강화) 창 → 그동안 말풍선 없음 →
// 닫으면 말풍선이 돌아와도 창과 겹치지 않는다.

/// 화면에 떠 있는 창(PixelDialog) 수와 옥토 말풍선(큰 것) 여부.
(int, bool) _count(WidgetTester tester) => (
  find.byType(PixelDialog).evaluate().length,
  find.byKey(const Key('talk')).evaluate().isNotEmpty,
);

void _expectOne(WidgetTester tester, String when) {
  final (dialogs, talk) = _count(tester);
  expect(dialogs, lessThanOrEqualTo(1), reason: '$when: 창 $dialogs개');
  if (dialogs > 0) expect(talk, isFalse, reason: '$when: 창 위에 옥토 말풍선이 겹침');
}

void main() {
  testWidgets('첫 보스 실패 → 맛보기 창 → 닫기까지 창·말풍선이 겹치지 않는다', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    // 튜토리얼을 마친 스테이지 3, 보스를 한 번 놓침(파밍) — 맛보기 '자동 강화'(afterBossFails 1) 조건.
    final base = loadFixture('stage37_midgame');
    final s = base.copyWith(
      progress: base.progress.copyWith(stage: 3, bestStage: 3, farming: true, bossFails: 1, trialsUsed: const []),
    );
    await pumpGame(
      tester,
      s,
      openTab: false,
      guides: true,
      trials: true,
      overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
    );
    feed.add(RecordedTick(s.battle!, const [BossFailed(1, stage: 3)]));
    for (var i = 0; i <= trialQuietSec + 3; i++) {
      await tester.pump(const Duration(seconds: 1));
      _expectOne(tester, '$i초');
    }
    expect(find.byKey(const Key('trial.offer.autoUpgrade')), findsOneWidget, reason: '45초 뒤 맛보기 창');
    await tester.tap(find.byKey(const Key('trial.later')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
      _expectOne(tester, '닫은 뒤 $i초');
    }
  });

  testWidgets('복귀 창으로 시작: 받기 전엔 말풍선·맛보기 없음 → 받은 뒤 45초가 지나야 맛보기', (tester) async {
    final base = loadFixture('stage37_midgame');
    final s = base.copyWith(progress: base.progress.copyWith(bestStage: 37, trialsUsed: const []));
    await pumpGame(
      tester,
      s,
      openTab: false,
      guides: true,
      trials: true,
      clock: FixedClock(s.savedAt.add(const Duration(hours: 2))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('offline.claim')), findsOneWidget, reason: '복귀 창이 먼저');
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(seconds: 1));
      _expectOne(tester, '복귀 창 $i초');
    }
    expect(find.byKey(const Key('trial.offer.speed')), findsNothing, reason: '복귀 창이 떠 있는 동안 맛보기 없음');
    await tester.tap(find.byKey(const Key('offline.claim')));
    await tester.pumpAndSettle();
    for (var i = 0; i <= trialQuietSec + 3; i++) {
      await tester.pump(const Duration(seconds: 1));
      _expectOne(tester, '받은 뒤 $i초');
    }
  });
}

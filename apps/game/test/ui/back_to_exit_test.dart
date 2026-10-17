import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/back_to_exit.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';

import 'ui_harness.dart';

// 뒤로 가기 두 번 = 종료 (사용자 2026-10-18) · 실기기 묶음(빈 결과 창 숨김 · 칸이 열리면 자동 출전).

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
}

void main() {
  testWidgets('시트가 열려 있으면 뒤로 = 시트 닫기(종료 안 함)', (tester) async {
    var exits = 0;
    await pumpGame(
      tester,
      loadFixture('stage37_midgame'),
      tab: 1,
      overrides: [appExitProvider.overrideWithValue(() async => exits++)],
    );
    await _back(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sheet.panel')), findsNothing);
    expect(exits, 0);
  });

  testWidgets('닫을 게 없으면 한 번 = 토스트만, 두 번(2초 안) = 저장 후 종료', (tester) async {
    var exits = 0;
    var saves = 0;
    final s = loadFixture('stage37_midgame');
    final clock = FixedClock(s.savedAt);
    await pumpGame(
      tester,
      s,
      openTab: false,
      clock: clock,
      overrides: [
        appExitProvider.overrideWithValue(() async => exits++),
        exitSaveProvider.overrideWithValue(() async => saves++),
      ],
    );
    await _back(tester);
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(exits, 0);
    await _back(tester);
    await tester.pump();
    expect(saves, 1);
    expect(exits, 1);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('러시를 아무것도 못 하고 끝났으면(0/5 · 보상 없음) 빈 결과 창을 띄우지 않는다', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(RecordedTick(s.battle!, const [RushEnded(1, killed: 0, ticks: 0, reason: 'interrupted')]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rush.result')), findsNothing);
  });

  testWidgets('출전 칸이 새로 열리면 빈 칸에 쉬는 선원 중 가장 센 선원을 넣는다', (tester) async {
    // 직접 편성한 3명 + 쉬는 스타리(옥토와 같은 레벨).
    final base = loadFixture('stage37_midgame');
    final t = GameTables.load();
    final s = base.copyWith(
      crews: {...base.crews, 'starry': base.crews['octo']!},
      fleet: activeFleet(base, t),
      fleetInit: true,
    );
    final log = await pumpGame(tester, s, openTab: false);
    // 스테이지를 올려 배 등급이 바뀌면 칸이 는다(표 shipTiers) — 칸 수가 느는 스테이지를 찾는다.
    final before = fleetSlots(s, t);
    var stage = s.progress.stage;
    var next = s;
    while (fleetSlots(next, t) <= before && stage < 500) {
      stage++;
      next = s.copyWith(
        progress: s.progress.copyWith(stage: stage, bestStage: stage),
      );
    }
    expect(fleetSlots(next, t), greaterThan(before), reason: '시험 전제: 칸이 느는 스테이지가 있다');
    replaceState(tester, next);
    await tester.pump();
    expect(log.sent.whereType<SetFleetSlot>().map((c) => c.crewId), contains('starry'));
  });
}

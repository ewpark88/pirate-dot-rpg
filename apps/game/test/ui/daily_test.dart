import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/meta/daily_providers.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

DailyQuestsView _quests({required int done, bool claimed = false}) {
  const types = ['kill', 'upgrade', 'summon', 'ad'];
  const targets = [500, 30, 1, 1];
  final quests = [
    for (var i = 0; i < 4; i++)
      QuestView(id: 'q$i', type: types[i], progress: i < done ? targets[i] : 0, target: targets[i]),
  ];
  return DailyQuestsView(quests: quests, rewardGems: 40, canClaim: done == 4 && !claimed, claimed: claimed);
}

AttendanceView _attendance({required bool claimedToday}) => AttendanceView(
  day: 4,
  claimedToday: claimedToday,
  rewards: [
    for (var d = 1; d <= 6; d++) AttendanceReward(gems: d * 10),
    const AttendanceReward(ticket: true),
  ],
);

/// 경제 함수(B7·B8)가 오기 전이라 provider를 가짜로 덮는다.
Future<CommandLog> _pump(WidgetTester tester, {DailyQuestsView? quests, AttendanceView? attendance}) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = loadFixture('stage37_midgame');
  final log = CommandLog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(state),
        commandSinkProvider.overrideWithValue(log),
        battleViewBuilderProvider.overrideWithValue((_) => const SizedBox()),
        clockProvider.overrideWithValue(FixedClock(state.savedAt)),
        dailyQuestsProvider.overrideWithValue((_) => quests),
        attendanceProvider.overrideWithValue((_, _) => attendance),
      ],
      child: const PirateDotApp(locale: Locale('en')),
    ),
  );
  await tester.pump();
  return log;
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('daily.icon')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('경제 함수 전(기본값)에는 퀘스트 아이콘이 없다', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.byKey(const Key('daily.icon')), findsNothing);
  });

  testWidgets('기준 5: 3/4 완료 → 빨간 점 없음, 받기 비활성', (tester) async {
    await _pump(tester, quests: _quests(done: 3), attendance: _attendance(claimedToday: true));
    expect(find.byKey(const Key('daily.dot')), findsNothing);
    await _openSheet(tester);
    expect(find.text('Defeat 500 monsters'), findsOneWidget);
    expect(find.text('500/500'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget); // 광고 퀘스트
    expect(tester.widget<FilledButton>(find.byKey(const Key('daily.claim'))).onPressed, isNull);
  });

  testWidgets('기준 5: 4/4 미수령 → 빨간 점, 받기 → ClaimDaily', (tester) async {
    final log = await _pump(tester, quests: _quests(done: 4), attendance: _attendance(claimedToday: true));
    expect(find.byKey(const Key('daily.dot')), findsOneWidget);
    await _openSheet(tester);
    expect(find.text('Complete all: Gems +40'), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily.claim')));
    expect(log.sent, [isA<ClaimDaily>()]);
  });

  testWidgets('이미 받았으면 ‘Claimed’', (tester) async {
    await _pump(tester, quests: _quests(done: 4, claimed: true), attendance: _attendance(claimedToday: true));
    await _openSheet(tester);
    expect(find.text('Claimed'), findsOneWidget);
    expect(find.byKey(const Key('daily.claim')), findsNothing);
  });

  testWidgets('기준 6: 출석 오늘 미수령 → 빨간 점, 받기 → ClaimAttendance, 7일차는 소환권', (tester) async {
    final log = await _pump(tester, quests: _quests(done: 0), attendance: _attendance(claimedToday: false));
    expect(find.byKey(const Key('daily.dot')), findsOneWidget);
    await _openSheet(tester);
    expect(find.byKey(const Key('attendance.day.4.today')), findsOneWidget);
    expect(find.text('Hero+ Summon'), findsOneWidget);
    await tester.tap(find.byKey(const Key('attendance.claim')));
    expect(log.sent, [isA<ClaimAttendance>()]);
  });

  testWidgets('기준 6: 출석 수령 후 → 오늘 칸 체크, 받기 없음', (tester) async {
    await _pump(tester, quests: _quests(done: 0), attendance: _attendance(claimedToday: true));
    await _openSheet(tester);
    expect(find.byKey(const Key('attendance.claim')), findsNothing);
    expect(find.byKey(const Key('attendance.day.4.checked')), findsOneWidget);
    expect(find.byKey(const Key('attendance.day.3.checked')), findsOneWidget);
    expect(find.byKey(const Key('attendance.day.5.checked')), findsNothing);
  });
}

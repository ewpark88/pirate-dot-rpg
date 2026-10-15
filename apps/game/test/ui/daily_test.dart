import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/app.dart';
import 'package:pirate_dot/ui/meta/daily_providers.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

/// 퀘스트 4개: 앞의 [done]개 달성, [claimed]개 받음. 보상은 meta.dailyQuestRewardGems(10).
List<QuestView> _quests({required int done, int claimed = 0}) {
  const types = ['kill', 'upgrade', 'summon', 'ad'];
  const targets = [500, 30, 1, 1];
  return [
    for (var i = 0; i < 4; i++)
      QuestView(
        id: 'q$i',
        type: types[i],
        progress: i < done ? targets[i] : 0,
        target: targets[i],
        claimed: i < claimed,
      ),
  ];
}

/// 출석 칸 보상은 실제 테이블 그대로 (20·20·30·30·40·50 + 7일차 영웅 확정).
AttendanceView _attendance({required bool claimedToday}) => AttendanceView(
  day: 4,
  claimedToday: claimedToday,
  rewards: GameTables.load().meta.raw.obj('attendance').objs('rewards'),
);

/// 경제 함수(B7·B8)가 오기 전이라 provider를 가짜로 덮는다.
Future<CommandLog> _pump(WidgetTester tester, {List<QuestView>? quests, AttendanceView? attendance}) async {
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
  testWidgets('기본값은 경제 dailyQuests·attendance — 샘플(kill 140/500, 출석 4일차)', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.byKey(const Key('daily.icon')), findsOneWidget);
    await _openSheet(tester);
    expect(find.text('140/500'), findsOneWidget);
    expect(find.text('+10'), findsNWidgets(4)); // 보상은 meta.dailyQuestRewardGems
  });

  testWidgets('기준 5: 달성했지만 받은 것뿐이면 빨간 점 없음', (tester) async {
    await _pump(tester, quests: _quests(done: 2, claimed: 2), attendance: _attendance(claimedToday: true));
    expect(find.byKey(const Key('daily.dot')), findsNothing);
    await _openSheet(tester);
    expect(find.text('Defeat 500 monsters'), findsOneWidget);
    expect(find.text('Claimed'), findsNWidgets(2));
    // 미달성 줄은 받기 비활성, 진행이 보인다
    expect(tester.widget<PixelButton>(find.byKey(const Key('daily.claim.q3'))).onPressed, isNull);
    expect(find.text('0/1'), findsNWidgets(2));
  });

  testWidgets('기준 5: 달성·미수령 줄이 있으면 빨간 점, 그 줄 받기 → ClaimDaily(id)', (tester) async {
    final log = await _pump(tester, quests: _quests(done: 3, claimed: 1), attendance: _attendance(claimedToday: true));
    expect(find.byKey(const Key('daily.dot')), findsOneWidget);
    await _openSheet(tester);
    expect(find.text('+10'), findsNWidgets(3)); // 받기 버튼 3개(1개는 받음)
    await tester.tap(find.byKey(const Key('daily.claim.q1')));
    expect(log.sent.map((c) => c.toJson()), [const ClaimDaily('q1').toJson()]);
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

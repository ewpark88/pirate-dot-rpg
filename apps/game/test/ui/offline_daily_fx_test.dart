import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/meta/daily_attendance.dart';
import 'package:pirate_dot/ui/offline/offline_fx.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 복귀·출석 창 HD 결 (S1 2026-10-18): 받을 골드는 0부터 굴러 올라 정확한 값에서 멈춤 · 출석은 받는 순간 도장이 크게 → 제자리.

AttendanceView _view({required bool claimed}) => AttendanceView(
  day: 4,
  claimedToday: claimed,
  rewards: GameTables.load().meta.raw.obj('attendance').objs('rewards'),
);

Widget _app(Widget child) => ProviderScope(
  overrides: [initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame'))],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('골드 굴림: 처음엔 작다가 0.9초 뒤 정확히 그 값', (tester) async {
    final v = BigNum.from(123456);
    await tester.pumpWidget(_app(RollUpGold(value: v)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(v.format()), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(v.format()), findsWidgets);
  });

  testWidgets('출석: 받는 순간 오늘 칸에 도장이 크게 찍혔다 제자리 · 지난 칸은 이미 찍힘', (tester) async {
    await tester.pumpWidget(_app(DailyAttendance(_view(claimed: false))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attendance.stamp.3')), findsOneWidget);
    expect(find.byKey(const Key('attendance.stamp.4')), findsNothing);
    await tester.pumpWidget(_app(DailyAttendance(_view(claimed: true))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // 그린 자리(Transform 포함)로 본다: 찍히는 중엔 크고, 끝나면 제 크기.
    final mid = tester.getRect(find.byKey(const Key('attendance.stamp.4'))).width;
    await tester.pumpAndSettle();
    final end = tester.getRect(find.byKey(const Key('attendance.stamp.4'))).width;
    expect(mid, greaterThan(end * 1.3));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/state/idle.dart';

import 'ui_harness.dart';

// 발열·배터리·OLED 잔상 대책 (사용자 지시 2026-10-16): 방치 단계 · 절전 덮개 · 미세 이동.

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

Future<(FixedClock, CommandLog)> _pump(WidgetTester tester, {Size? size, double? dpr, Locale? locale}) async {
  final s = loadFixture('stage37_midgame');
  final clock = FixedClock(s.savedAt);
  final log = await pumpGame(
    tester,
    s,
    clock: clock,
    size: size ?? s24Size,
    dpr: dpr ?? s24Dpr,
    locale: locale ?? const Locale('en'),
    openTab: false,
  );
  return (clock, log);
}

IdleLevel _level(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeScreen))).read(idleLevelProvider);

void main() {
  testWidgets('60초 입력 없음 = idle, 3분 = 절전 덮개 · 덮개를 누르면 복귀하고 그 누름은 게임에 안 간다', (tester) async {
    final (clock, log) = await _pump(tester);
    expect(_level(tester), IdleLevel.active);
    clock.time = clock.time.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 5));
    expect(_level(tester), IdleLevel.idle);
    expect(find.byKey(const Key('idle.sleep')), findsNothing);
    clock.time = clock.time.add(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 5));
    expect(_level(tester), IdleLevel.sleep);
    expect(find.byKey(const Key('idle.sleep')), findsOneWidget);
    expect(find.text('Touch the screen to return'), findsOneWidget);
    // 덮개 아래 퀵 강화 자리를 눌러도 명령이 나가지 않는다.
    await tester.tapAt(tester.getCenter(find.byKey(const Key('quick.upgrade'))));
    await tester.pump();
    expect(find.byKey(const Key('idle.sleep')), findsNothing);
    expect(_level(tester), IdleLevel.active);
    expect(log.sent, isEmpty);
  });

  testWidgets('입력이 있으면 방치 시계가 되돌아간다', (tester) async {
    final (clock, _) = await _pump(tester);
    clock.time = clock.time.add(const Duration(seconds: 50));
    await tester.tapAt(const Offset(200, 400));
    clock.time = clock.time.add(const Duration(seconds: 50));
    await tester.pump(const Duration(seconds: 5));
    expect(_level(tester), IdleLevel.active);
  });

  testWidgets('잔상 방지: 2분마다 화면이 1~2dp 미세 이동', (tester) async {
    final (clock, _) = await _pump(tester);
    Offset shift() => tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => Offset(t.transform.getTranslation().x, t.transform.getTranslation().y))
        .firstWhere((o) => o != Offset.zero, orElse: () => Offset.zero);
    expect(shift(), Offset.zero);
    clock.time = clock.time.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 5));
    final o = shift();
    expect(o.distance, inInclusiveRange(0.5, 2.01));
  });

  testWidgets('설정 절전 모드를 끄면 절전 화면 없음(방치 신호 idle만)', (tester) async {
    final s = loadFixture('stage37_midgame');
    final off = s.copyWith(settings: s.settings.withValue('powerSave', false));
    final clock = FixedClock(s.savedAt);
    await pumpGame(tester, off, clock: clock, openTab: false);
    clock.time = clock.time.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(_level(tester), IdleLevel.idle);
    expect(find.byKey(const Key('idle.sleep')), findsNothing);
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);

    for (final (name, size, dpr) in _devices) {
      testWidgets('절전 화면 $name', (tester) async {
        final (clock, _) = await _pump(tester, size: size, dpr: dpr, locale: const Locale('ko'));
        clock.time = clock.time.add(const Duration(minutes: 4));
        await tester.pump(const Duration(seconds: 5));
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_idle_sleep_$name.png'));
      });
    }
  });
}

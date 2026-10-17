import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/crew/swap_compare.dart';
import 'package:pirate_dot/ui/home_screen.dart';

import 'ui_harness.dart';

// 선원 교체 비교 창(사용자 피드백 #34): 지금 vs 새 선원 초상·초당 피해·±%·차이·결론 칩·[교체][취소].

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

void main() {
  GameState state() {
    final s = loadFixture('stage37_midgame');
    return s.copyWith(crews: {...s.crews, 'pang': s.crews['pang']!.copyWith(level: 60)});
  }

  String outOf(GameState s) => s.battle!.fleet.first.crewId;

  Future<Future<bool>> open(WidgetTester tester, String out, String inn) async {
    final ctx = tester.element(find.byType(HomeScreen));
    final r = showSwapCompare(ctx, out, inn);
    await tester.pumpAndSettle();
    return r;
  }

  testWidgets('강한 선원으로 바꾸면 추천 · +% · 교체는 true, 취소는 false', (tester) async {
    final s = state();
    await pumpGame(tester, s, openTab: false);
    final out = outOf(s);
    final r = await open(tester, out, 'pang');
    expect(find.byKey(const Key('swap.compare')), findsOneWidget);
    expect(find.byKey(Key('swap.side.$out')), findsOneWidget);
    expect(find.byKey(const Key('swap.side.pang')), findsOneWidget);
    expect(find.byKey(const Key('swap.verdict.better')), findsOneWidget);
    expect(find.textContaining('Attack/s +'), findsOneWidget);
    await tester.tap(find.byKey(const Key('swap.confirm')));
    await tester.pumpAndSettle();
    expect(await r, isTrue);
    final back = await open(tester, 'pang', out);
    expect(find.byKey(const Key('swap.verdict.worse')), findsOneWidget);
    await tester.tap(find.byKey(const Key('swap.cancel')));
    await tester.pumpAndSettle();
    expect(await back, isFalse);
  });

  testWidgets('창은 작다: 폭 85% · 최대 340dp(태블릿은 앱이 1.4배로 그려 화면에선 480 이하), 버튼 48dp 이상', (tester) async {
    final s = state();
    await pumpGame(tester, s, size: const Size(800, 1280), dpr: 2, openTab: false);
    unawaited(await open(tester, outOf(s), 'pang'));
    final box = tester.getRect(find.byKey(const Key('swap.compare.box')));
    expect(box.width, lessThanOrEqualTo(480));
    expect(tester.getSize(find.byKey(const Key('swap.confirm'))).height, greaterThanOrEqualTo(48));
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in _devices) {
      testWidgets('교체 비교 $name ko', (tester) async {
        final s = state();
        await pumpGame(tester, s, size: size, dpr: dpr, locale: const Locale('ko'), openTab: false);
        unawaited(await open(tester, outOf(s), 'pang'));
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_swap_compare_$name.png'));
      });
    }
    testWidgets('교체 비교 s24 en', (tester) async {
      final s = state();
      await pumpGame(tester, s, openTab: false);
      unawaited(await open(tester, outOf(s), 'pang'));
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_swap_compare_s24.png'));
    });
  });
}

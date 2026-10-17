import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 보스 브레이크 (사용자 결정 2026-10-17, specs/platform-fever-break.md 2): 보스 시간 막대 아래 브레이크 막대 + 쓰러지면 'BREAK!'.

GameState _boss({double ratio = 0, bool broken = false, bool active = true, double cooldown = 0}) {
  final s = loadFixture('boss_fight');
  return s.copyWith(
    battle: s.battle!.copyWith(
      bossActive: active,
      enemies: [
        EnemyView(
          id: 1,
          kind: 'giant_hermit',
          x: 135,
          y: 120,
          hpRatio: 1,
          boss: true,
          breakRatio: ratio,
          broken: broken,
          breakCooldown: cooldown,
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('보스전: 게이지 안 브레이크 막대가 breakRatio만큼 찬다(보스 시간 막대 아래)', (tester) async {
    await pumpGame(tester, _boss(ratio: 0.4), openTab: false);
    expect(find.byKey(const Key('hud.break')), findsOneWidget);
    final fill = tester.widget<FractionallySizedBox>(find.byKey(const Key('hud.break.fill')));
    expect(fill.widthFactor, closeTo(0.4, 0.001));
    final timer = tester.getRect(find.byKey(const Key('hud.gauge.timer')));
    expect(tester.getRect(find.byKey(const Key('hud.break'))).top, greaterThanOrEqualTo(timer.bottom));
    expect(find.bySemanticsLabel('Boss break 40%'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('폰 피드백 v2: 막대 두께 ≥ 10dp, 80% 넘으면 hot(흔들림·빛), 쓰러진 동안 금빛 가득, 쿨다운이면 회색 + 자물쇠 + 시계', (tester) async {
    await pumpGame(tester, _boss(ratio: 0.5), openTab: false);
    final bar = find.descendant(of: find.byKey(const Key('hud.break')), matching: find.byType(Container)).last;
    expect(tester.getSize(bar).height, greaterThanOrEqualTo(10));
    expect(find.byKey(const Key('hud.break.hot')), findsNothing);
    await pumpGame(tester, _boss(ratio: 0.85), openTab: false);
    expect(find.byKey(const Key('hud.break.hot')), findsOneWidget);
    await pumpGame(tester, _boss(broken: true), openTab: false);
    final full = tester.widget<FractionallySizedBox>(find.byKey(const Key('hud.break.full')));
    expect(full.widthFactor, 1);
    expect(find.byKey(const Key('hud.break.lock')), findsNothing);
    // 쿨다운(EnemyView.breakCooldown): 회색 + 자물쇠 + 차오르는 시계(1 - 남은 비율).
    await pumpGame(tester, _boss(cooldown: 0.75), openTab: false);
    expect(find.byKey(const Key('hud.break.lock')), findsOneWidget);
    expect(
      tester.widget<CircularProgressIndicator>(find.byKey(const Key('hud.break.clock'))).value,
      closeTo(0.25, 0.02),
    );
    await pumpGame(tester, _boss(ratio: 0.1), openTab: false);
    expect(find.byKey(const Key('hud.break.lock')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('보스전이 아니면 브레이크 막대 없음', (tester) async {
    await pumpGame(tester, _boss(active: false), openTab: false);
    expect(find.byKey(const Key('hud.break')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('BossBroken → 보스 자리에 BREAK! 잠깐, 1.4초 뒤 사라짐', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _boss(ratio: 1);
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    expect(find.byKey(const Key('hud.break.burst')), findsNothing);
    feed.add(RecordedTick(s.battle!, const [BossBroken(5, enemyId: 1, ticks: 60, x: 135, y: 120)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('BREAK!'), findsOneWidget);
    final area = tester.getRect(find.byKey(const Key('battle.area')));
    expect(area.contains(tester.getCenter(find.byKey(const Key('hud.break.burst')))), isTrue);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const Key('hud.break.burst')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  for (final (name, size, dpr) in [
    ('360', const Size(360, 640), 3.0),
    ('s24', s24Size, s24Dpr),
    ('411', const Size(411, 891), 2.625),
    ('tablet', const Size(800, 1280), 2.0),
  ]) {
    testWidgets('골든 4기기: 브레이크 막대 85%(hot) $name', (tester) async {
      await loadGoldenFonts();
      await pumpGame(tester, _boss(ratio: 0.85), openTab: false, size: size, dpr: dpr, locale: const Locale('ko'));
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_boss_break_$name.png'));
      await tester.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('골든: 쓰러진 동안 금빛 BREAK! (s24)', (tester) async {
    await loadGoldenFonts();
    await pumpGame(tester, _boss(broken: true), openTab: false, locale: const Locale('ko'));
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_boss_break_broken_s24.png'));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('골든: 쿨다운 회색 + 자물쇠 + 시계 (s24)', (tester) async {
    await loadGoldenFonts();
    await pumpGame(tester, _boss(cooldown: 0.5), openTab: false, locale: const Locale('ko'));
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_boss_break_cooldown_s24.png'));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('골든: 영어 보스전 브레이크 막대 60% (s24)', (tester) async {
    await loadGoldenFonts();
    await pumpGame(tester, _boss(ratio: 0.6), openTab: false);
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_boss_break_s24.png'));
    await tester.pump(const Duration(seconds: 5));
  });
}

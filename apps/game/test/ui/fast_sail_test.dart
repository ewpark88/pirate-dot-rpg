import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/home_screen.dart';

import 'ui_harness.dart';

// 빠른 항해 돌파 UI (기획 platform-fast-sail-breakthrough 'UI (S4)', 사용자 결정 2026-10-16).

GameState _run({int rebirths = 1, int stage = 18, int combo = 3}) {
  final s = withCargoRoom(loadFixture('stage37_midgame'));
  return s.copyWith(
    progress: s.progress.copyWith(stage: stage, rebirths: rebirths),
    // BattleView.copyWith에 fastSail이 없어 JSON으로 만든다.
    battle: BattleView.fromJson({
      ...s.battle!.toJson(),
      'fastSail': FastSailView(from: 10, to: 40, combo: combo, phase: 'rush', speed: 4).toJson(),
    }),
  );
}

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

/// 구간이 끝난 전장 (fastSail 없음).
BattleView _ended(GameState s) => BattleView.fromJson({...s.battle!.toJson()}..remove('fastSail'));

void main() {
  testWidgets('구간 중: 우상단 패널(빠른 항해 n/m · 보스 연속 격파), 1회차는 건너뛰기 없음', (tester) async {
    await pumpGame(tester, _run(), openTab: false);
    await tester.pumpAndSettle();
    final panel = find.byKey(const Key('fastSail.banner'));
    expect(panel, findsOneWidget);
    expect(find.text('Fast sail 9/31'), findsOneWidget); // 10~40 중 18 = 9번째
    expect(find.text('Boss streak 3'), findsOneWidget);
    // 피드백 #20: 오른쪽 위 — 패널이 화면 오른쪽 절반에 있고 전장 가운데를 덮지 않는다.
    final box = tester.getRect(panel);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(box.left, greaterThan(screen.width / 2 - 20));
    expect(box.width, lessThanOrEqualTo(196));
    expect(find.byKey(const Key('fastSail.skip')), findsNothing);
  });

  testWidgets('2회차부터 건너뛰기 → SkipFastSail', (tester) async {
    final log = await pumpGame(tester, _run(rebirths: 2), openTab: false);
    await tester.tap(find.byKey(const Key('fastSail.skip')));
    expect(log.sent.whereType<SkipFastSail>(), hasLength(1));
  });

  testWidgets('끝: 요약 창(돌파 스테이지·골드·젬·더 강해진 당신) + 넘친 골드면 화물칸 강화 바로가기', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _run();
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed
      ..add(RecordedTick(s.battle!, const [FastSailStarted(1, from: 10, to: 40)]))
      ..add(RecordedTick(s.battle!, [GoldOverflow(2, lost: BigNum.parse('3e4'))]))
      ..add(
        RecordedTick(_ended(s), [
          FastSailEnded(
            3,
            from: 10,
            to: 40,
            stages: 30,
            gold: BigNum.parse('1.2e5'),
            lost: BigNum.parse('3e4'),
            gems: 15,
            skipped: false,
          ),
        ]),
      )
      // 바로 다음 보급(S5 ShipResupplied): 창에 '배가 강해졌다!' + 오른 부위만.
      ..add(
        RecordedTick(_ended(s), const [
          ShipResupplied(4, stage: 41, before: {'cannon': 0, 'sail': 5}, after: {'cannon': 25, 'sail': 5}),
        ]),
      );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fastSail.end')), findsOneWidget);
    expect(find.byKey(const Key('fastSail.resupply')), findsOneWidget);
    expect(find.text('Cannon Lv 0 → 25'), findsOneWidget);
    expect(find.textContaining('Sail Lv'), findsNothing);
    expect(find.text('Stages 10 → 40 cleared!'), findsOneWidget);
    expect(find.text('30 bosses defeated'), findsOneWidget);
    expect(find.text('Gold +120K'), findsOneWidget);
    expect(find.text('Gems +15'), findsOneWidget);
    expect(find.text('Gold lost to a full cargo hold: 30K'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fastSail.cargo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fastSail.end')), findsNothing);
    // 바로가기는 배 탭을 연다(요청은 홈 화면이 처리하고 비운다 → 배 탭 패널이 보인다).
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    expect(c.read(dockTabRequestProvider), isNull);
    expect(find.byKey(const Key('ship.upgrade.cannon')), findsOneWidget);
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);

    for (final (name, size, dpr) in _devices) {
      testWidgets('빠른 항해 패널 $name', (tester) async {
        await pumpGame(
          tester,
          _run(rebirths: 2),
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
          openTab: false,
        );
        await tester.pumpAndSettle();
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_fast_sail_$name.png'));
      });
    }

    testWidgets('돌파 끝 요약 360', (tester) async {
      final feed = StreamController<RecordedTick>.broadcast(sync: true);
      addTearDown(feed.close);
      final s = _run();
      await pumpGame(
        tester,
        s,
        size: const Size(360, 640),
        dpr: 3,
        locale: const Locale('ko'),
        openTab: false,
        overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
      );
      feed
        ..add(RecordedTick(s.battle!, [GoldOverflow(2, lost: BigNum.parse('3e4'))]))
        ..add(
          RecordedTick(_ended(s), [
            FastSailEnded(
              3,
              from: 10,
              to: 40,
              stages: 30,
              gold: BigNum.parse('1.2e5'),
              lost: BigNum.parse('3e4'),
              gems: 15,
              skipped: false,
            ),
          ]),
        );
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_fast_sail_end_360.png'));
    });
  });
}

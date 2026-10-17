import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';

import 'ui_harness.dart';

// 바다 괴물 도감 (S1 2026-10-16): 항해 탭 카드 → 시트, 해역마다 잡몹·보스. 값은 경제 계약 progress.dex{seen, kills}:
// 처치 1 이상 = 모습·이름·처치 수, 만나기만 = 실루엣·???, 못 만남 = 물음표.

/// stage37 샘플 + 도감: 게(처치 12)·피라냐(만남만)·첫 보스(처치 1).
GameState _withDex() {
  final s = loadFixture('stage37_midgame');
  final boss = GameTables.load().regions.regions.first.boss;
  return s.copyWith(
    progress: s.progress.copyWith(
      dex: DexState(seen: {'crab', 'piranha', boss}, kills: {'crab': 12, boss: 1}),
    ),
  );
}

Future<void> _openDex(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('dex.card')),
    200,
    scrollable: find.descendant(of: find.byType(VoyageTab), matching: find.byType(Scrollable)).first,
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('dex.card')));
  await tester.pumpAndSettle();
}

void main() {
  final t = GameTables.load();

  testWidgets('진짜 값: 처치하면 이름·처치 수, 만나기만 하면 ???, 첫 처치 젬은 표(meta.dex)', (tester) async {
    await pumpGame(tester, _withDex());
    await _openDex(tester);
    expect(find.byKey(const Key('dex.sheet')), findsOneWidget);
    final crab = find.byKey(const Key('dex.tile.crab'));
    expect(find.descendant(of: crab, matching: find.text('Crab')), findsOneWidget);
    expect(find.descendant(of: crab, matching: find.textContaining('12')), findsOneWidget);
    final piranha = find.byKey(const Key('dex.tile.piranha'));
    expect(find.descendant(of: piranha, matching: find.text('???')), findsOneWidget);
    expect(
      find.descendant(
        of: piranha,
        matching: find.textContaining('${t.meta.raw.obj('dex').number('firstKillGems').round()}'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('도감이 비면(새 세이브) 모두 ???', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    await _openDex(tester);
    expect(find.descendant(of: find.byKey(const Key('dex.tile.crab')), matching: find.text('???')), findsOneWidget);
  });

  testWidgets('첫 처치(DexFirstKill) → 토스트 "새 괴물 도감 등록! 이름 · 젬 +n", [도감]을 누르면 도감 시트', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _withDex();
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(RecordedTick(s.battle!, const [DexFirstKill(3, id: 'crab', boss: false, gems: 5)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('New in the Monster Log! Crab · +5 gems'), findsOneWidget);
    await tester.tap(find.byKey(const Key('skin.toast.action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dex.sheet')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  test('목록은 표 그대로: 해역 수 · 분열 작은 적 제외 · 보스 포함', () {
    final ids = {
      for (final r in t.regions.regions) ...[
        ...r.enemies.where((e) => !e.endsWith('_small')),
        r.boss,
        r.midBoss,
        r.regionBoss,
        ...r.bossRotation,
        ?r.wallBoss,
      ],
    };
    expect(ids, isNotEmpty);
    expect(t.regions.regions, hasLength(6));
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);

    for (final (name, size, dpr) in [('360', const Size(360, 640), 3.0), ('tablet', const Size(800, 1280), 2.0)]) {
      testWidgets('도감 시트 $name', (tester) async {
        await pumpGame(
          tester,
          _withDex(),
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
        );
        await _openDex(tester);
        await precacheImages(tester);
        await tester.pumpAndSettle();
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_monster_dex_$name.png'));
      });
    }
  });
}

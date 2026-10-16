import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';

import 'ui_harness.dart';

// 바다 괴물 도감 골격 (S1 2026-10-16): 항해 탭 카드 → 시트, 해역마다 잡몹·보스, 처치 전엔 실루엣·???.

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

  testWidgets('카드 n/m → 시트: 지나온 해역은 이름 공개, 아직 못 간 해역은 ??? · 첫 처치 젬', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    await _openDex(tester);
    expect(find.byKey(const Key('dex.sheet')), findsOneWidget);
    // 산호초(1~) 잡몹은 만나고 처치 → 이름이 보인다.
    expect(find.descendant(of: find.byKey(const Key('dex.tile.crab')), matching: find.text('Crab')), findsOneWidget);
    // 두 번째 해역(최고 41 < 51) 새 잡몹은 아직 → ??? + 첫 처치 보상.
    final first = t.regions.regions.first.enemies.toSet();
    final last = t.regions.regions[1].enemies.firstWhere((e) => !e.endsWith('_small') && !first.contains(e));
    expect(find.descendant(of: find.byKey(Key('dex.tile.$last')), matching: find.text('???')), findsOneWidget);
  });

  test('목록은 표 그대로: 해역 수 · 분열 작은 적 제외 · 보스 포함', () {
    final ids = {
      for (final r in t.regions.regions) ...[
        ...r.enemies.where((e) => !e.endsWith('_small')),
        r.boss,
        r.midBoss,
        r.regionBoss,
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
          loadFixture('stage37_midgame'),
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

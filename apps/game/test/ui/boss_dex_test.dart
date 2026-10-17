import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/dex/boss_dex_detail.dart';
import 'package:pirate_dot/ui/dex/monster_dex_data.dart';
import 'package:pirate_dot/ui/home_screen.dart';

import 'ui_harness.dart';

// 몬스터 도감 보스 상세 (S1 2026-10-18): 만난 보스 = 체력·공격·패턴·다음 등장, 못 만난 보스 = 실루엣 + '스테이지 n에서 등장'.

final _t = GameTables.load();

void main() {
  test('다음 등장 스테이지는 표 regions.bossAt 그대로', () {
    final id = _t.regions.bossAt(10).id;
    expect(bossNextStage(_t, id, 10), 10);
    expect(_t.regions.bossAt(bossNextStage(_t, id, 11)!).id, id);
  });

  testWidgets('만난 보스: 체력·패턴·다음 등장', (tester) async {
    final s = loadFixture('stage37_midgame');
    final id = _t.regions.bossAt(5).id;
    final met = s.copyWith(
      progress: s.progress.copyWith(
        dex: DexState(seen: {id}, kills: {id: 3}),
      ),
    );
    await pumpGame(tester, met, openTab: false);
    showBossDex(
      tester.element(find.byType(HomeScreen)),
      DexEntry(id: id, boss: true, met: true, defeated: true, kills: 3),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(Key('dex.boss.$id')), findsOneWidget);
    expect(find.byKey(const Key('dex.boss.hp')), findsOneWidget);
    expect(find.byKey(const Key('dex.boss.next')), findsOneWidget);
    // 처음 등장 때 체력·공격은 경제 bossDexView 값 그대로.
    final row = bossDexView(met, _t).firstWhere((e) => e.id == id);
    expect(find.text('When it first appears: HP ${row.hp.format()} · Attack ${row.attack.format()}'), findsOneWidget);
    if (_t.regions.bosses[id]!.patterns.isNotEmpty) expect(find.byKey(const Key('dex.boss.patterns')), findsOneWidget);
  });

  testWidgets('못 만난 보스: 실루엣 + 스테이지 n에서 등장', (tester) async {
    final s = loadFixture('stage37_midgame');
    final id = _t.regions.bossAt(300).id;
    await pumpGame(tester, s, openTab: false);
    showBossDex(tester.element(find.byType(HomeScreen)), DexEntry(id: id, boss: true, met: false, defeated: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('Appears at stage'), findsOneWidget);
    expect(find.byKey(const Key('dex.boss.hp')), findsNothing);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in const [('360', Size(360, 640), 3.0), ('tablet', Size(800, 1280), 2.0)]) {
      testWidgets('보스 상세 ko $name', (tester) async {
        final s = loadFixture('stage37_midgame');
        final id = _t.regions.bossAt(5).id;
        await pumpGame(tester, s, openTab: false, size: size, dpr: dpr, locale: const Locale('ko'));
        showBossDex(
          tester.element(find.byType(HomeScreen)),
          DexEntry(id: id, boss: true, met: true, defeated: true, kills: 3),
        );
        await tester.pumpAndSettle();
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_boss_dex_$name.png'));
      });
    }
  });
}

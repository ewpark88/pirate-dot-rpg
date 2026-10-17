import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

import 'ui_harness.dart';

// 일괄 합치기 결과 팝업 (사용자 2026-10-18): 누르기 전·뒤 상태를 비교 — 초상 모여 '쾅', 선원마다 Lv 굴림·공격력 전→후·
// 등급이 오르면 배지, 함대 전투력 전→후.

final _t = GameTables.load();

/// 옥토를 [up]레벨 올린 상태(엔진이 합치기를 처리한 것처럼).
GameState _leveled(GameState s, String id, int up) => s.copyWith(
  crews: {
    ...s.crews,
    id: s.crews[id]!.copyWith(level: s.crews[id]!.level + up),
  },
);

Future<void> _merge(WidgetTester tester, GameState s, GameState after) async {
  await tester.tap(find.byKey(const Key('crew.mergeAll')));
  replaceState(tester, after);
  await tester.pump(const Duration(milliseconds: 300));
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('옥토 +3레벨: 결과 창 · 그 줄 · 함대 전투력', (tester) async {
    final s = loadFixture('stage37_midgame');
    await pumpGame(tester, s, tab: 2);
    await _merge(tester, s, _leveled(s, 'octo', 3));
    expect(find.byKey(const Key('merge.result')), findsOneWidget);
    expect(find.byKey(const Key('merge.row.octo')), findsOneWidget);
    expect(find.byKey(const Key('merge.fleet')), findsOneWidget);
  });

  testWidgets('등급 경계를 넘으면 등급 배지', (tester) async {
    final s = loadFixture('stage37_midgame');
    final octo = s.crews['octo']!.level;
    final r0 = rarityOfLevel(_t.rarities, octo).id;
    var up = 1;
    while (rarityOfLevel(_t.rarities, octo + up).id == r0 && up < 200) {
      up++;
    }
    await pumpGame(tester, s, tab: 2);
    await _merge(tester, s, _leveled(s, 'octo', up));
    expect(find.byKey(const Key('merge.rarity.octo')), findsOneWidget);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in const [
      ('360', Size(360, 640), 3.0),
      ('384', s24Size, s24Dpr),
      ('411', Size(411, 891), 2.625),
      ('tablet', Size(800, 1280), 2.0),
    ]) {
      testWidgets('합치기 결과 ko $name', (tester) async {
        final s = loadFixture('stage37_midgame');
        await pumpGame(tester, s, tab: 2, size: size, dpr: dpr, locale: const Locale('ko'));
        final ids = s.crews.keys.take(3).toList();
        var after = s;
        for (final id in ids) {
          after = _leveled(after, id, 4);
        }
        await _merge(tester, s, after);
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_merge_result_$name.png'));
      });
    }
  });
}

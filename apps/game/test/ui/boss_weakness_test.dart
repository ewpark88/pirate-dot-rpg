import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

import 'ui_harness.dart';

/// boss_fight 샘플의 보스를 [kind]로 바꾼다.
GameState _bossFight(String kind, {bool active = true}) {
  final s = loadFixture('boss_fight');
  final battle = s.battle!;
  return s.copyWith(
    battle: battle.copyWith(
      bossActive: active,
      enemies: [EnemyView(id: 1, kind: kind, x: 240, y: 90, hpRatio: 1, boss: true)],
    ),
  );
}

void main() {
  final tables = GameTables.load();

  test('보스 nameKey와 약점 계열 nameKey는 모두 문구가 있다 (table_text 연결)', () {
    for (final b in tables.regions.bosses.values) {
      expect(b.nameKey, startsWith('battleBoss'), reason: b.id);
      for (final f in b.weakFamilies) {
        expect(tables.skills.byId(f).nameKey, isNotEmpty, reason: '${b.id}/$f');
      }
    }
  });

  testWidgets('기준 4: 소라게 보스 — 이름, 약점 칩 Lob·Air (테이블 순서)', (tester) async {
    await pumpGame(tester, _bossFight('giant_hermit'));
    final weak = find.byKey(const Key('boss.weak'));
    expect(weak, findsOneWidget);
    expect(find.descendant(of: weak, matching: find.text('Weak')), findsOneWidget);
    // 칩은 테이블 순서대로 (lob → air), 글자는 계열 이름.
    final chips = find.descendant(of: weak, matching: find.byWidgetPredicate((w) => '${w.key}'.contains('boss.weak.')));
    final texts = [
      for (final e in chips.evaluate())
        tester.widget<Text>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text))).data,
    ];
    expect(texts, ['Lob', 'Air']);
  });

  testWidgets('기준 4: 약점 없는 보스(enemy_ship)는 표시 없음', (tester) async {
    await pumpGame(tester, _bossFight('enemy_ship'));
    expect(find.byKey(const Key('boss.weak')), findsNothing);
  });

  testWidgets('기준 4: 보스전이 아니면 표시 없음', (tester) async {
    await pumpGame(tester, _bossFight('giant_hermit', active: false));
    expect(find.byKey(const Key('boss.weak')), findsNothing);
  });
}

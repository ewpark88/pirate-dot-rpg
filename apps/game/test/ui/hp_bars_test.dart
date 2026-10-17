import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

import 'ui_harness.dart';

// 체력 수치 (사용자 2026-10-17 '내 배 체력·보스 체력이 안 보인다. 수치로 예쁘게').

void main() {
  final t = GameTables.load();

  testWidgets('배 체력: 선원 줄 바로 위 전폭 ♥ 남은 / 최대 (평소에도)', (tester) async {
    final s = loadFixture('stage37_midgame');
    final half = s.copyWith(battle: s.battle!.copyWith(shipHp: s.battle!.shipHpMax.times(0.3)));
    await pumpGame(tester, half, openTab: false);
    expect(find.text('${half.battle!.shipHp.format()} / ${half.battle!.shipHpMax.format()}'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(find.byKey(const Key('hud.shipHp.bar')));
    expect(bar.value, closeTo(0.3, 0.01));
    expect(bar.color, const Color(0xFFFFC53D), reason: '40% 아래 노랑');
    final hp = tester.getRect(find.byKey(const Key('hud.shipHp')));
    final slot = tester.getRect(find.byKey(const Key('fleet.crew.0')));
    expect(hp.bottom, lessThanOrEqualTo(slot.top + 1));
  });

  testWidgets('보스 체력: 게이지 안 굵은 막대 · 이름 · 남은 / 최대(bossPreview × 비율)', (tester) async {
    final s = loadFixture('boss_fight');
    final fight = s.copyWith(
      battle: s.battle!.copyWith(
        enemies: [const EnemyView(id: 1, kind: 'giant_hermit', x: 135, y: 120, hpRatio: 0.5, boss: true)],
      ),
    );
    await pumpGame(tester, fight, openTab: false);
    final max = bossPreview(fight.copyWith(clearTutorial: true), t).maxHp;
    expect(find.textContaining('${max.times(0.5).format()} / ${max.format()}'), findsOneWidget);
    expect(find.textContaining('Giant Hermit'), findsWidgets);
  });
}

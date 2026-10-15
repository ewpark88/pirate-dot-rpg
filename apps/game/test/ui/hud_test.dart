import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'ui_harness.dart';

void main() {
  // 골드·스테이지·함성 게이지는 캔버스 HUD(render)가 그린다 — UI는 누르는 것만 전장 위에 남긴다.
  testWidgets('기준 1: Material HUD가 없고, 젬은 소환 탭에', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: summonTab);
    expect(find.text('Stage 37-2'), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('summon.gems')), matching: find.text('140')), findsOneWidget);
  });

  testWidgets('기준 1: 누르는 것(설정·궁극기)은 전장 상자 안', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    final area = tester.getRect(find.byKey(const Key('battle.area')));
    for (final key in ['hud.settings', 'hud.ultimate']) {
      final r = tester.getRect(find.byKey(Key(key)));
      expect(area.contains(r.topLeft) && area.contains(r.bottomRight - const Offset(1, 1)), isTrue, reason: key);
    }
    // 궁극기는 선원 슬롯 줄(논리 y 148~180) 위
    final k = area.width / 320;
    expect(tester.getRect(find.byKey(const Key('hud.ultimate'))).bottom, lessThanOrEqualTo(area.top + 148 * k));
  });

  testWidgets('기준 2: 보스전이면 남은 초 (400틱 × 50ms = 20초)', (tester) async {
    await pumpGame(tester, loadFixture('boss_fight'));
    expect(find.text('Boss 20s'), findsOneWidget);
  });

  testWidgets('기준 2: 보스전이 아니면 타이머가 없다', (tester) async {
    await pumpGame(tester, loadFixture('new_player'));
    expect(find.textContaining('Boss'), findsNothing);
  });

  testWidgets('기준 3: 함성이 덜 찼으면 궁극기 버튼 비활성', (tester) async {
    final log = await pumpGame(tester, loadFixture('stage37_midgame'));
    await tester.tap(find.byKey(const Key('hud.ultimate')));
    expect(log.sent, isEmpty);
  });

  testWidgets('기준 3: 함성이 가득이면 누를 때 TriggerUltimate 1개', (tester) async {
    final base = loadFixture('stage37_midgame');
    final full = base.copyWith(progress: base.progress.copyWith(rage: 1));
    final log = await pumpGame(tester, full);
    await tester.tap(find.byKey(const Key('hud.ultimate')));
    expect(log.sent, [isA<TriggerUltimate>()]);
  });
}

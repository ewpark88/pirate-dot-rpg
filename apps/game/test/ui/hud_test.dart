import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/hud/top_bar.dart';

import 'ui_harness.dart';

void main() {
  // 화면 배치 v2 (layout-v2-brief): 골드·젬·퀘스트·설정은 전장 밖 상단 바, 전장 필드 안에는 누르는 것이 없다.
  testWidgets('기준 1: 상단 바에 골드·젬·설정, 모두 전장 위(밖)', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.descendant(of: find.byType(TopBar), matching: find.text('1.25M')), findsOneWidget);
    expect(find.descendant(of: find.byType(TopBar), matching: find.text('140')), findsOneWidget);
    final area = tester.getRect(find.byKey(const Key('battle.area')));
    for (final key in ['top.gold', 'top.gems', 'hud.settings']) {
      expect(tester.getRect(find.byKey(Key(key))).bottom, lessThanOrEqualTo(area.top + 0.5), reason: key);
    }
    // #9 A: 퀘스트는 상단이 아니라 도크 첫 칸(엄지 자리) — 전장 아래, 항해는 도크 끝.
    final quest = tester.getRect(find.byKey(const Key('daily.icon')));
    expect(quest.top, greaterThanOrEqualTo(area.bottom - 0.5));
    final tabs = [
      for (final i in [1, 2, 3, 0]) tester.getRect(find.byKey(Key('tab.$i'))).left,
    ];
    expect(quest.left, lessThan(tabs.first));
    expect(tabs, orderedEquals([...tabs]..sort()), reason: '[퀘스트][배][선원][소환][항해]');
  });

  // 사용자 결정 2026-10-17: 궁극기 버튼 제거(피버 첫 일격) — 선원 줄 오른쪽에는 보스 도전만.
  testWidgets('기준 1: 궁극기 버튼 없음, 선원 칸을 눌러도 TriggerUltimate 없음', (tester) async {
    final log = await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.byKey(const Key('hud.ultimate')), findsNothing);
    expect(log.sent.whereType<TriggerUltimate>(), isEmpty);
  });

  testWidgets('기준 2: 보스 남은 초는 캔버스(렌더)가 그린다 — UI 오버레이 없음', (tester) async {
    await pumpGame(tester, loadFixture('boss_fight'));
    expect(find.text('Boss 20s'), findsNothing);
  });
}

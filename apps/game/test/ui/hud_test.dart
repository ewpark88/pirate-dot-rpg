import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/ui/hud/top_bar.dart';

import 'ui_harness.dart';

void main() {
  // 화면 배치 v2 (layout-v2-brief): 골드·젬·퀘스트·설정은 전장 밖 상단 바, 전장 필드 안에는 누르는 것이 없다.
  testWidgets('기준 1: 상단 바에 골드·젬·설정, 모두 전장 위(밖)', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(find.descendant(of: find.byType(TopBar), matching: find.text('1.25M')), findsOneWidget);
    expect(find.descendant(of: find.byType(TopBar), matching: find.text('140')), findsOneWidget);
    final area = tester.getRect(find.byKey(const Key('battle.area')));
    for (final key in ['top.gold', 'top.gems', 'hud.settings', 'daily.icon']) {
      expect(tester.getRect(find.byKey(Key(key))).bottom, lessThanOrEqualTo(area.top + 0.5), reason: key);
    }
  });

  // 사용자 결정(S3 d8d4a68): 궁극기는 오른쪽 끝 칸 바로 위 둥근 버튼 — 선원 칸과 겹치지 않는다.
  testWidgets('기준 1: 궁극기는 오른쪽 끝 칸 위(battleFrameFor.ultimateRect), 칸과 겹치지 않음', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    final area = tester.getRect(find.byKey(const Key('battle.area')));
    final f = battleFrameFor(area.size, s24Dpr);
    final ult = tester.getRect(find.byKey(const Key('hud.ultimate')));
    expect(ult.center, offsetMoreOrLessEquals(area.topLeft + f.ultimateRect.center, epsilon: 0.5));
    expect(f.ultimateRect.bottom, lessThanOrEqualTo(f.slotRects.last.top + 0.5));
    expect(f.ultimateRect.overlaps(f.slotRects.last), isFalse);
    expect(ult.width, greaterThanOrEqualTo(48));
  });

  testWidgets('기준 2: 보스 남은 초는 캔버스(렌더)가 그린다 — UI 오버레이 없음', (tester) async {
    await pumpGame(tester, loadFixture('boss_fight'));
    expect(find.text('Boss 20s'), findsNothing);
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/hud/boss_compare.dart';

import 'ui_harness.dart';

// 보스 재도전 표시 (S3 첫 15분 점검 2026-10-17): 실패 뒤 파밍 중, 보스 vs 나가 '여유'면 도전 버튼 위 '이길 수 있어요!'.

void main() {
  final t = GameTables.load();

  GameState farming(GameState s, {int cannonUp = 0}) => s.copyWith(
    progress: s.progress.copyWith(farming: true),
    ship: s.ship.withLevel('cannon', s.ship.level('cannon') + cannonUp),
  );

  testWidgets('여유(level 0)면 이길 수 있어요! · 어려우면 없음', (tester) async {
    final strong = farming(loadFixture('stage37_midgame'), cannonUp: 400);
    expect(bossCompareOf(strong, t)?.level, 0, reason: '시험 전제: 대포를 크게 올리면 여유');
    await pumpGame(tester, strong, openTab: false);
    expect(find.byKey(const Key('boss.canWin')), findsOneWidget);

    final weak = farming(loadFixture('stage37_midgame'));
    final level = bossCompareOf(weak, t)?.level;
    await pumpGame(tester, weak, openTab: false);
    expect(find.byKey(const Key('boss.canWin')), level == 0 ? findsOneWidget : findsNothing);
  });
}

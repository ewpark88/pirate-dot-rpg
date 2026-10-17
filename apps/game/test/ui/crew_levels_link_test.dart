import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 선원 칸 큰 Lv(S3 렌더): 계약에 레벨이 없어 UI가 BattleGame.crewLevels로 넣는다 — 처음과 레벨이 바뀔 때.

void main() {
  test('전장에 선원 레벨이 들어가고, 레벨이 오르면 바뀐다', () {
    final s = loadFixture('stage37_midgame');
    final c = ProviderContainer(overrides: [initialGameStateProvider.overrideWithValue(s)]);
    addTearDown(c.dispose);
    final game = c.read(battleGameProvider);
    final id = s.crews.keys.first;
    expect(game.scene.crewLevels[id], s.crews[id]!.level);
    final up = s.copyWith(
      crews: {
        ...s.crews,
        id: s.crews[id]!.copyWith(level: s.crews[id]!.level + 1),
      },
    );
    c.read(gameStateProvider.notifier).replace(up);
    expect(game.scene.crewLevels[id], s.crews[id]!.level + 1);
  });

  testWidgets('띠 아래 끝 + 8dp를 전장 hudTopDp로(S3 보스 카메라 안전 영역)', (tester) async {
    await pumpGame(
      tester,
      loadFixture('stage37_midgame'),
      openTab: false,
      overrides: [hasBattleGameProvider.overrideWithValue(true)],
    );
    await tester.pump();
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final gauge = tester.getRect(find.byKey(const Key('hud.gauge')));
    final area = tester.getRect(find.byKey(const Key('battle.area')));
    // 띠는 바깥 여백(위 2dp)까지 재므로 상자 아래 끝 − 전장 위 + 8과 같다.
    expect(c.read(battleGameProvider).scene.hudTopDp, closeTo(gauge.bottom - area.top + 8, 0.5));
  });
}

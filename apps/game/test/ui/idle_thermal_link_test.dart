import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/adapters/power/power_channel.dart';
import 'package:pirate_dot/power_policy.dart';
import 'package:pirate_dot/render/battle_game.dart' as render show IdleLevel;
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/state/idle.dart';

import 'ui_harness.dart';

// S3 요청 render-idle-thermal-link: 방치 단계·발열 단계의 원본(UI)을 전장(BattleGame.idle)이 그대로 따른다.

void main() {
  testWidgets('만들자마자 UI 단계를 따르고(스스로 세지 않음), 바뀌면 바로 넘어간다 — 절전 화면 = 렌더 dim', (tester) async {
    final container = ProviderContainer(
      overrides: [initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame'))],
    );
    addTearDown(container.dispose);
    final game = container.read(battleGameProvider);
    expect(game.idle.following, isTrue);
    expect(game.idle.level.value, render.IdleLevel.active);

    final idle = container.read(idleLevelProvider.notifier);
    final t0 = idle.lastInput;
    idle.evaluate(t0.add(idleAfter));
    expect(game.idle.level.value, render.IdleLevel.idle);
    idle.evaluate(t0.add(sleepAfterDefault));
    expect(game.idle.level.value, render.IdleLevel.dim);
    idle.touch(t0.add(sleepAfterDefault));
    expect(game.idle.level.value, render.IdleLevel.active);
  });

  testWidgets('발열 단계 index가 game.idle.heat로 — 보통 이상이면 가벼운 그리기', (tester) async {
    final container = ProviderContainer(
      overrides: [initialGameStateProvider.overrideWithValue(loadFixture('stage37_midgame'))],
    );
    addTearDown(container.dispose);
    final game = container.read(battleGameProvider);
    expect(game.idle.heat.value, 0);
    container.read(thermalLevelProvider.notifier).set(ThermalLevel.moderate);
    expect(game.idle.heat.value, ThermalLevel.moderate.index);
    expect(game.idle.lite, isTrue);
    container.read(thermalLevelProvider.notifier).set(ThermalLevel.none);
    expect(game.idle.lite, isFalse);
  });

  test('단계 대응표', () {
    expect(IdleLevel.values.map(renderIdleOf), [render.IdleLevel.active, render.IdleLevel.idle, render.IdleLevel.dim]);
  });
}

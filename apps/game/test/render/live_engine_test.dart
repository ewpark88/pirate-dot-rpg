import 'dart:ui' as ui;

import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:pirate_dot/engine_host.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';

import 'helpers.dart';

/// M2 관문 준비: 실제 엔진(EngineHost) 출력을 라이브로 재생하고, 측정 오버레이가 live에서도 뜨는지.
void main() {
  test('실제 엔진 30초 라이브 재생 — 적이 나오고 처치가 생기며 오버레이가 뜬다', () async {
    final clock = ManualClock(DateTime.utc(2026, 10, 14));
    final host = EngineHost(
      tables: tables,
      initial: GameState.newGame(playerId: 'test', seed: 7, now: clock.now(), crews: tables.meta.startingCrews),
      clock: clock,
    );
    final game = BattleGame(feed: host.ticks, tables: tables, perfOverlay: true, loadSprites: false)
      ..onGameResize(Vector2(kLogicalWidth * 3, kLogicalHeight * 3));
    await game.onLoad();
    expect(game.mode, BattleMode.live);

    var maxEnemies = 0;
    var kills = 0;
    host.ticks.listen((t) => kills += t.events.whereType<Kill>().length);
    const frames = 60 * 30;
    for (var f = 0; f < frames; f++) {
      // 엔진 20Hz, 화면 60Hz.
      if (f % 3 == 0) {
        clock.advance(host.engine.tickLength);
        host.step();
      }
      game.update(1 / 60);
      if (game.stats.enemies > maxEnemies) maxEnemies = game.stats.enemies;
    }

    expect(game.scene.player.position, greaterThan(500), reason: '라이브 재생이 엔진을 따라간다');
    expect(game.scene.player.bufferedTicks, lessThan(64));
    expect(maxEnemies, greaterThan(0));
    expect(kills, greaterThan(0));
    expect(game.overlayReady, isTrue);
    expect(game.fps, closeTo(60, 1));

    // 실제 엔진 프레임을 그려도 예외가 없다.
    final rec = ui.PictureRecorder();
    paintTopStd(ScenePainter(game.scene), ui.Canvas(rec));
    rec.endRecording().dispose();
    game.onRemove();
    host.stop();
  });
}

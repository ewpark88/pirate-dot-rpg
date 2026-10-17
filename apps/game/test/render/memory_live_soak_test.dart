import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:pirate_dot/engine_host.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import 'helpers.dart';

/// 전체 품질 점검 도구(S1 요청 — 골든 아님): 실제 엔진(EngineHost)으로 새 게임 첫 15분을 사람처럼(튜토리얼 확인·가끔 강화·소환)
/// 돌리며 30초마다 s24 전투 장면 한 장과 그 30초의 이벤트 요약을 STRIP_DIR에 쓴다. STRIP_DIR이 없으면 건너뛴다.
///   STRIP_DIR=... flutter test test/render/first15_strip_test.dart
void main() {
  final minutes = int.tryParse(Platform.environment['SOAK_MIN'] ?? '');
  testWidgets('라이브 장시간 메모리(진단 — SOAK_MIN 분)', skip: minutes == null, (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final clock = ManualClock(DateTime.utc(2026, 10, 17));
    final host = EngineHost(
      tables: tables,
      initial: GameState.newGame(playerId: 'soak', seed: 21, now: clock.now(), crews: tables.meta.startingCrews),
      clock: clock,
    );
    const dpr = 2.8125;
    const box = ui.Size(384, 832 - 48 - 24 - 76);
    final game = BattleGame(feed: host.ticks, tables: tables, loadSprites: false)
      ..onGameResize(Vector2(box.width, box.height));
    await game.onLoad();
    game.scene.layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(game.scene)..sprites = bank;
    final frame = topFrameFor(box, dpr);
    host
      ..send(const TutorialAck(1))
      ..send(const UpgradePart('cannon'));
    const fps = 30;
    for (var sec = 0; sec < minutes! * 60; sec++) {
      for (var f = 0; f < fps; f++) {
        if (f % 3 == 0) {
          clock.advance(host.engine.tickLength);
          host.step();
        }
        clock.advance(host.engine.tickLength * 0.5);
        host.step();
        game.update(1 / fps);
        painter.paintTop(ui.Canvas(ui.PictureRecorder()), frame);
      }
      if (sec % 20 == 10) host.send(const ChallengeBoss());
      if (sec % 5 == 0) {
        for (final p in const ['cannon', 'hull', 'sail', 'cargo', 'crowsnest']) {
          host.send(UpgradePart.max(p));
        }
      }
      if (sec % 60 == 59) {
        final s = game.scene;
        // ignore: avoid_print — 진단 출력
        print(
          'min ${sec ~/ 60 + 1} rss ${ProcessInfo.currentRss ~/ 1048576}MB stage ${host.state.progress.stage} '
          '${painter.top.memory()} bank ${bank.length} fx ${s.effects.active.length} coins ${s.coins.active.length} '
          'nums ${s.numbers.active.length} buf ${s.player.bufferedTicks}',
        );
      }
    }
    game.onRemove();
    host.stop();
  });
}

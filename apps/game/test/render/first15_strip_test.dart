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
  final dir = Platform.environment['STRIP_DIR'];
  testWidgets('첫 15분 프레임 띠(30초마다)', skip: dir == null, (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final clock = ManualClock(DateTime.utc(2026, 10, 17));
    final host = EngineHost(
      tables: tables,
      initial: GameState.newGame(playerId: 'strip', seed: 21, now: clock.now(), crews: tables.meta.startingCrews),
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
    final log = StringBuffer();
    final counts = <String, int>{};
    host.ticks.listen((t) {
      for (final e in t.events) {
        if (e is Damage || e is Kill || e is EnemyFired || e is EnemyWindup) continue;
        counts[e.type] = (counts[e.type] ?? 0) + 1;
      }
    });
    host
      ..send(const TutorialAck(1))
      ..send(const UpgradePart('cannon'));
    const fps = 30; // 그리기는 30fps로 줄여도 장면은 같다(엔진 20Hz)
    for (var sec = 0; sec < 15 * 60; sec++) {
      for (var f = 0; f < fps; f++) {
        if (f % 3 == 0) {
          // 엔진 20Hz ≈ 화면 30fps에서 3장마다 2틱
          clock.advance(host.engine.tickLength);
          host.step();
        }
        clock.advance(host.engine.tickLength * 0.5);
        host.step();
        game.update(1 / fps);
        painter.paintTop(ui.Canvas(ui.PictureRecorder()), frame);
      }
      // 사람처럼: 5초마다 강화, 1분마다 튜토리얼 확인·소환·자동 편성, 20초마다 보스 도전
      if (sec % 20 == 10) host.send(const ChallengeBoss()); // 보스 실패 뒤 다시 도전(사람이 버튼을 누르듯)
      if (sec % 5 == 0) {
        for (final p in const ['cannon', 'hull', 'sail', 'cargo', 'crowsnest']) {
          host.send(UpgradePart.max(p));
        }
      }
      if (sec % 60 == 30) {
        host
          ..send(const TutorialAck(4))
          ..send(const TutorialAck(6))
          ..send(const Summon(count: 10))
          ..send(const AckSummonResult())
          ..send(const AutoFleet())
          ..send(const MergeAllCards());
      }
      if (sec % 30 == 29) {
        final n = sec ~/ 30 + 1;
        final rec = ui.PictureRecorder();
        final c = ui.Canvas(rec)..scale(dpr);
        painter.paintTop(c, frame);
        final img = await tester.runAsync(
          () => rec.endRecording().toImage((box.width * dpr).round(), (box.height * dpr).round()),
        );
        final png = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
        File('$dir/f${n.toString().padLeft(2, '0')}.png').writeAsBytesSync(png!.buffer.asUint8List());
        final s = host.state;
        log.writeln(
          'f$n ${sec + 1}s stage ${s.progress.stage} best ${s.progress.bestStage} hull ${s.ship.level('hull')} '
          'gold ${s.wallet.gold} crews ${s.crews.length} | ${counts.entries.map((e) => '${e.key}:${e.value}').join(' ')}',
        );
        counts.clear();
      }
    }
    File('$dir/log.txt').writeAsStringSync(log.toString());
    game.onRemove();
    host.stop();
  });
}

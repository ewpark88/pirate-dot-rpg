import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

/// 단색 이미지 (테스트용 스프라이트).
Future<ui.Image> _solid(int w, int h, int argb) async {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = ui.Color(argb));
  return rec.endRecording().toImage(w, h);
}

Future<int> _pixel(ScenePainter painter, int x, int y) async {
  final rec = ui.PictureRecorder();
  painter.paint(ui.Canvas(rec));
  final img = await rec.endRecording().toImage(kLogicalWidth.toInt(), kLogicalHeight.toInt());
  final bytes = (await img.toByteData())!;
  final i = (y * img.width + x) * 4;
  final rgba = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  return (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
}

void main() {
  test('경로 표: 초상 40명·적 시트 2프레임·이펙트 프레임·배·코인', () {
    final paths = SpriteBank.manifest(tables);
    expect(paths.where((p) => p.key.startsWith('crew:')).length, tables.crews.crews.length);
    expect(paths.firstWhere((p) => p.key == 'crew:octo').path, 'crews/octo.png');
    final crab = paths.firstWhere((p) => p.key == 'enemy:crab');
    expect((crab.path, crab.frames), ('enemies/crab.png', tables.fxMap.sprites.integer('enemyFrames')));
    final fx = paths.firstWhere((p) => p.key == 'fx:explosion_aoe');
    expect((fx.path, fx.frames), ('fx/explosion_aoe.png', tables.fxMap.sheet('explosion_aoe')!.frames));
    expect(paths.firstWhere((p) => p.key == 'projectile:lob').path, 'projectiles/cannonball.png');
    expect(paths.firstWhere((p) => p.key == 'ship').path, 'ship/ship_t1.png');
    expect(paths.firstWhere((p) => p.key == 'boss:enemy_ship').path, 'bosses/enemy_ship.png');
    expect(paths.firstWhere((p) => p.key == 'coin').frames, tables.fxMap.sprites.integer('coinFrames'));
  });

  testWidgets('수용 기준 5: 스프라이트가 있으면 그것으로, 번쩍이면 흰색, 없으면 플레이스홀더', (tester) async {
    await tester.runAsync(() async {
      final ticks = [
        tickOf(0, enemies: [(1, 200)]),
        tickOf(
          1,
          enemies: [(1, 200)],
          events: [Damage(1, targetId: 1, amount: BigNum.from(1))],
        ),
        for (var t = 2; t < 10; t++) tickOf(t, enemies: [(1, 200)]),
      ];
      final bank = SpriteBank()..put('enemy:crab', await _solid(32, 12, 0xFF0000FF), frames: 2);
      final scene = BattleScene(tables, ticks, loop: false);
      final painter = ScenePainter(scene)..sprites = bank;

      // 맞기 전: 파란 스프라이트.
      scene.update(kFrameMs);
      expect(await _pixel(painter, 200, 100), 0x0000FF);

      // 맞은 직후: 흰 번쩍임.
      while (scene.player.position < 1) {
        scene.update(kFrameMs);
      }
      expect(scene.poseOf(1)!.flash, isTrue);
      expect(await _pixel(painter, 200, 100), 0xFFFFFF);

      // 스프라이트 끄기 → 플레이스홀더 색(basic).
      for (var i = 0; i < 10; i++) {
        scene.update(kFrameMs);
      }
      painter.useSprites = false;
      expect(await _pixel(painter, 200, 100), tables.fxMap.enemyLook['basic']!.color & 0xFFFFFF);
    });
  });

  test('빈 뱅크는 아무것도 없다', () {
    expect(SpriteBank().isEmpty, isTrue);
    expect(SpriteBank()['enemy:crab'], isNull);
  });
}

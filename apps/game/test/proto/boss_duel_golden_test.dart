import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import '../render/helpers.dart';
import '../render/top_recording.dart';

/// 보스전 v2(배가 화면 가운데로 올라가 보스와 마주 보며 돎) — 실제 엔진 보스전을 렌더로 그린 프레임 띠, 4기기.
/// 보스 등장 뒤 0.3·1·2·4·6·8초. 한 장 = 프레임 6개 가로.
const _framesSec = [0.3, 1.0, 2.0, 4.0, 6.0, 8.0];

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640 - 148), 3.0),
  ('s24', Size(384, 832 - 148), 2.8125),
  ('411', Size(411, 891 - 148), 2.625),
  ('tablet', Size(800, 1280 - 148), 2.0),
];

void main() {
  final rec = topRecording(tables, ticks: 260, stage: 120, bossAt: 10); // 120: 보스가 몇 초 버틴다
  final start = rec.indexWhere((t) => t.events.any((e) => e is BossSpawned));
  final tickSec = tables.waves.tickMs / 1000;

  test('기록에 보스전이 있고 배가 위로 올라가 머리를 돌린다', () {
    expect(start, greaterThanOrEqualTo(0));
    final later = rec[start + (4 / tickSec).round()].frame;
    expect(later.shipY, lessThan(tables.waves.top.shipY));
  });

  for (final (name, box, dpr) in _devices) {
    testWidgets('보스전 v2 프레임 띠 $name', (tester) async {
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final w = box.width.round();
      final h = box.height.round();
      final strip = ui.PictureRecorder();
      final canvas = ui.Canvas(strip);
      for (final (i, sec) in _framesSec.indexed) {
        final at = start + (sec / tickSec).round();
        while (scene.player.position < at) {
          scene.update(kFrameMs);
          painter.paintTop(ui.Canvas(ui.PictureRecorder()), frame);
        }
        canvas
          ..save()
          ..translate(i * (w + 4).toDouble(), 0)
          ..clipRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
        painter.paintTop(canvas, frame);
        canvas.restore();
      }
      final image = await tester.runAsync(() => strip.endRecording().toImage(_framesSec.length * (w + 4), h));
      await expectLater(image, matchesGoldenFile('goldens/boss_duel_$name.png'));
    });
  }
}

import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import '../render/helpers.dart';
import '../render/top_recording.dart';
import '../ui/ui_harness.dart';

/// 바다 v2(디자인 개편 ③ — 한 단계 깊은 해역별 바다 + 흘러가는 외곽선 소품): 해역 6개 띠(s24) + 산호 해역 4기기.
const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640 - 148), 3.0),
  ('s24', Size(384, 832 - 148), 2.8125),
  ('411', Size(411, 891 - 148), 2.625),
  ('tablet', Size(800, 1280 - 148), 2.0),
];

Future<ui.Image> _strip(WidgetTester tester, List<int> stages, Size box, double dpr) async {
  final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
  final w = box.width.round();
  final h = box.height.round();
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  for (final (i, stage) in stages.indexed) {
    final scene = BattleScene(tables, topRecording(tables, ticks: 140, stage: stage), loop: false)
      ..layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(scene)..sprites = bank;
    final frame = topFrameFor(box, dpr);
    while (scene.player.position < 120) {
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
  return (await tester.runAsync(() => rec.endRecording().toImage(stages.length * (w + 4), h)))!;
}

void main() {
  setUpAll(loadGoldenFonts);
  const per = 50; // regions.json stagesPerRegion

  testWidgets('바다 v2 해역 6개 s24', (tester) async {
    final image = await _strip(tester, [for (var r = 0; r < 6; r++) r * per + 3], _devices[1].$2, _devices[1].$3);
    await expectLater(image, matchesGoldenFile('goldens/sea_v2_regions_s24.png'));
  });

  for (final (name, box, dpr) in _devices) {
    testWidgets('바다 v2 산호 $name', (tester) async {
      final image = await _strip(tester, [3], box, dpr);
      await expectLater(image, matchesGoldenFile('goldens/sea_v2_$name.png'));
    });
  }
}

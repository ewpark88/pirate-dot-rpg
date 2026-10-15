import 'dart:io';
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

/// 진단용(골든 아님): 탑다운 실제 기록을 프레임 띠로 남긴다. `TOP_STRIP=<폴더>`일 때만.
void main() {
  final dump = Platform.environment['TOP_STRIP'];
  testWidgets('탑다운 프레임 띠', (tester) async {
    if (dump == null) return;
    final rec = topRecording(tables, ticks: 260);
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const dpr = 2.8125;
    const box = Size(384, 832 - 48 - 24 - 76);
    final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(scene)..sprites = bank;
    final frame = topFrameFor(box, dpr);
    for (final at in [15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 195, 210, 225, 240]) {
      while (scene.player.position < at) {
        scene.update(kFrameMs);
        painter.paintTop(ui.Canvas(ui.PictureRecorder()), frame);
      }
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec)..scale(dpr);
      painter.paintTop(c, frame);
      final img = await tester.runAsync(
        () => rec.endRecording().toImage((box.width * dpr).round(), (box.height * dpr).round()),
      );
      final png = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
      File('$dump/f_${at.toString().padLeft(3, '0')}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
}

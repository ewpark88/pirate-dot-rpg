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
import '../ui/ui_harness.dart';

/// 피버 배 모션 'flow'(사용자 피드백 #24) — 실제 엔진 피버(게이지 0.99로 시작해 첫 처치에 켜짐)를 렌더로 그린 프레임 띠, 4기기.
/// 피버 시작 뒤 1·2.5·4.5·5·5.5·7.5초(넓고 긴 S자 — 원 돌기 없음, 사용자 피드백 8번). 한 장 = 프레임 6개 가로.
const _framesSec = [1.0, 2.5, 4.5, 5.0, 5.5, 7.5];

/// 전투 상자(상단 바·게이지·선원 줄·도크를 뺀 높이 — top_marks_golden_test와 같은 셈).
const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640 - 148), 3.0),
  ('s24', Size(384, 832 - 148), 2.8125),
  ('411', Size(411, 891 - 148), 2.625),
  ('tablet', Size(800, 1280 - 148), 2.0),
];

void main() {
  setUpAll(loadGoldenFonts); // BREAK! 도장 등 글자가 흰 상자로 나오지 않게(S3)
  final rec = topRecording(tables, ticks: 520, fever: 0.99);
  final start = rec.indexWhere((t) => t.events.any((e) => e is FeverStarted));
  final tickSec = tables.waves.tickMs / 1000;

  test('기록에 실제 피버가 있고, 피버 동안 배가 가운데에서 움직인다', () {
    expect(start, greaterThanOrEqualTo(0));
    final xs = [for (final t in rec.skip(start).take((8 / tickSec).round())) t.frame.shipX ?? 0];
    final spread = xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b);
    expect(spread, greaterThan(60));
  });

  for (final (name, box, dpr) in _devices) {
    testWidgets('피버 배 모션 프레임 띠 $name', (tester) async {
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      // 한 칸은 1 논리 px = 1 px로 작게(띠 전체가 너무 커지지 않게).
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
      await expectLater(image, matchesGoldenFile('goldens/fever_motion_$name.png'));
    });
  }
}

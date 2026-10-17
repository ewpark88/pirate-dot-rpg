import 'dart:ui' show PictureRecorder;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import 'helpers.dart';
import 'top_recording.dart';

/// 빠른 항해 보급(ShipResupplied): 오른 부위마다 낙하산 상자가 배로 떨어지고, 닿으면 금빛 고리 + 부위 빛. 주입, S24.
class _Painter extends CustomPainter {
  _Painter(this.painter, this.frame, this.dpr);
  final ScenePainter painter;
  final TopFrame frame;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(dpr);
    painter.paintTop(canvas, frame);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

void main() {
  for (final (name, after) in const [('fall', 450.0), ('land', 900.0)]) {
    testWidgets('보급 골든 s24 $name', (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      const at = 100;
      final base = topRecording(tables, ticks: 200);
      final rec = [
        for (var i = 0; i < base.length; i++)
          i == at
              ? RecordedTick(base[i].frame, [
                  ...base[i].events,
                  ShipResupplied(
                    base[i].frame.tick,
                    stage: 43,
                    before: const {'cannon': 24, 'hull': 40, 'sail': 10, 'crowsnest': 15},
                    after: const {'cannon': 60, 'hull': 70, 'sail': 30, 'crowsnest': 15},
                  ),
                ])
              : base[i],
      ];
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      while (scene.player.position < at + 1) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      final start = scene.clockMs;
      while (scene.clockMs - start < after) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      tester.view
        ..physicalSize = Size((box.width * dpr).roundToDouble(), (box.height * dpr).roundToDouble())
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: (box.width * dpr).roundToDouble(),
              height: (box.height * dpr).roundToDouble(),
              child: CustomPaint(painter: _Painter(painter, frame, dpr)),
            ),
          ),
        ),
      );
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_resupply_${name}_s24.png'));
    });
  }
}

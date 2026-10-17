import 'dart:ui' show PictureRecorder;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import '../ui/ui_harness.dart';
import 'helpers.dart';
import 'top_recording.dart';

/// 보스 브레이크 (사용자 '보스 브레이크가 잘 안 보여', BossBroken): 체력 막대 아래 노란 게이지(80%↑ 맥박) →
/// 깨지는 순간 충격파·유리 조각·'BREAK!' 도장 → 쓰러진 동안 기우뚱·별 빙빙·큰 피해 숫자. 실제 엔진 보스 + 주입(withBossBreak), S24.
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
  setUpAll(loadGoldenFonts);
  for (final (name, after) in const [('gauge', -300.0), ('stamp', 120.0), ('down', 900.0)]) {
    testWidgets('보스 브레이크 골든 s24 $name', (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      final base = topRecording(tables, ticks: 320, stage: 120, bossAt: 5);
      final at = base.indexWhere((t) => t.frame.enemies.any((e) => e.boss), 160);
      expect(at, greaterThan(0));
      final rec = withBossBreak(base, at: at);
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      final stop = at + (after < 0 ? after / tables.waves.tickMs : 1);
      while (scene.player.position < stop) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      if (after > 0) {
        final start = scene.clockMs;
        while (scene.clockMs - start < after) {
          scene.update(kFrameMs);
          painter.paintTop(warm, frame);
        }
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_break_${name}_s24.png'));
    });
  }
}

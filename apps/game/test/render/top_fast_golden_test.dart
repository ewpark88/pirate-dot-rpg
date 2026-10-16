import 'dart:ui' show PictureRecorder;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_fast_sail.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import '../ui/ui_harness.dart';
import 'helpers.dart';
import 'top_recording.dart';

/// 빠른 항해 돌파 (S5 fast-sail, 사용자 '웅대·꿈과 희망·점점 빨라져 순식간·피날레'): 시작 컷인, rush 격파(흰 터널·스탬프·콤보),
/// 피날레(돌파!). withFastSail 주입(시작 60틱). S24.
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
  final rec = withFastSail(topRecording(tables, ticks: 400));
  int first(bool Function(GameEvent e) f) => rec.indexWhere((t) => t.events.any(f));
  final cases = {
    'cutin': (60, 0.4),
    'rush': (first((e) => e is BreakthroughStrike && e.phase == 'rush'), 0.08),
    'finale': (first((e) => e is BreakthroughStrike && e.phase == 'finale'), 0.1),
  };
  for (final MapEntry(key: name, value: (at, after)) in cases.entries) {
    testWidgets('빠른 항해 골든 s24 $name', (tester) async {
      expect(at, greaterThan(0));
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      scene.topHits.fast.texts = TopTexts(
        start: '빠른 항해 돌파!',
        strike: '격파!',
        finale: '돌파!',
        ended: (from, to) => '스테이지 $from → $to 돌파!',
      );
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      final stop = at + after * 1000 / tables.waves.tickMs;
      while (scene.player.position < stop) {
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_fast_${name}_s24.png'));
    });
  }
}

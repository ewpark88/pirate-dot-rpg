import 'dart:ui' show PictureRecorder;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/text/outline_digits.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import '../ui/ui_harness.dart';
import 'helpers.dart';
import 'top_recording.dart';

/// 부위 마일스톤(S2 — 8레벨마다 효과 ×2): 배에서 솟는 금빛 빛기둥·금 고리·큰 '×2!'·그 부위 빛. S24.
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
  testWidgets('부위 마일스톤 골든 s24', (tester) async {
    const dpr = 2.8125;
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final digits = (await tester.runAsync(() => OutlineDigits.load(devicePixelRatio: dpr)))!;
    const box = Size(384, 832 - 48 - 24 - 76);
    final base = topRecording(tables, ticks: 260, stage: 40);
    final rec = [
      for (final (i, t) in base.indexed)
        RecordedTick(
          t.frame,
          i == 180 ? [...t.events, PartMilestone(i, part: 'cannon', level: 16)] : t.events,
        ),
    ];
    final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(scene)
      ..sprites = bank
      ..digits = digits;
    final frame = topFrameFor(box, dpr);
    final warm = Canvas(PictureRecorder());
    while (scene.player.position < 186) {
      scene.update(kFrameMs);
      painter.paintTop(warm, frame);
    }
    expect(scene.topHits.glow.milestoneAt, greaterThan(0));
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_milestone_s24.png'));
  });
}

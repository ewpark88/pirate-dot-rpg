import 'dart:ui' show PictureRecorder;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import 'helpers.dart';
import 'top_recording.dart';

/// 화물칸 가득 (S2 GoldOverflow, S1): 화물칸에서 금화가 양옆으로 넘쳐 바다에 떨어지고 'FULL'이 뜬다. 주입 틱 0.35초 뒤(S24).
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
  testWidgets('화물칸 가득 골든 s24', (tester) async {
    const dpr = 2.8125;
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const box = Size(384, 832 - 48 - 24 - 76);
    final rec = withGoldOverflow(topRecording(tables, ticks: 400));
    // 주입한 틱(엔진이 스스로 내는 피격은 고르지 않는다 — 선원 개성 v2 등으로 시각이 바뀌어도 같은 장면).
    const at = 120;
    final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(scene)..sprites = bank;
    final frame = topFrameFor(box, dpr);
    final warm = Canvas(PictureRecorder());
    while (scene.player.position < at) {
      scene.update(kFrameMs);
      painter.paintTop(warm, frame);
    }
    for (var i = 0; i < 21; i++) {
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_gold_overflow_s24.png'));
  });
}

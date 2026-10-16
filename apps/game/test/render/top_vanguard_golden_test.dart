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

/// 돌격대(붉은 테·물보라 꼬리·잔상)와 신화 착탄 폭발(splashRadius 30, 무지개 충격파) — 주입 장면, S24.
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
  testWidgets('돌격대·착탄 폭발 골든 s24', (tester) async {
    const dpr = 2.8125;
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const box = Size(384, 832 - 48 - 24 - 76);
    final rec = withVanguardSplash(topRecording(tables, ticks: 400, levels: const {'pang': 66, 'octo': 30}));
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
    for (var i = 0; i < 6; i++) {
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_vanguard_s24.png'));
  });
}

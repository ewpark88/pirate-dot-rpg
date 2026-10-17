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

import 'helpers.dart';
import 'top_recording.dart';

/// 디자인 개편 발광: 선원 스킬(SkillCast) 순간 배 밑 마법진(두 겹 고리·육각별·룬 눈금·번지는 빛, 계열 색). 실제 기록 첫 스킬 0.35초 뒤, S24.
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
  testWidgets('스킬 마법진 골든 s24', (tester) async {
    const dpr = 2.8125;
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final digits = (await tester.runAsync(() => OutlineDigits.load(devicePixelRatio: dpr)))!;
    const box = Size(384, 832 - 48 - 24 - 76);
    final rec = topRecording(tables, ticks: 300);
    final at = rec.indexWhere((t) => t.events.any((e) => e is SkillCast));
    expect(at, greaterThan(0), reason: '기록에 스킬이 있어야 한다');
    final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(scene)
      ..sprites = bank
      ..digits = digits;
    final frame = topFrameFor(box, dpr);
    final warm = Canvas(PictureRecorder());
    while (scene.player.position < at + 1) {
      scene.update(kFrameMs);
      painter.paintTop(warm, frame);
    }
    final start = scene.clockMs;
    while (scene.clockMs - start < 350) {
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_glow_s24.png'));
  });
}

import 'dart:ui' show PictureRecorder;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import 'helpers.dart';
import 'top_recording.dart';

/// 탑다운 표시 골든 (T4-3 — 옆모습 화가만 그리던 것): 수중 구역, 정예 고리·보호막·상태 아이콘, 떠내려온 보물상자, 배 강화 테.
/// 장면 상태를 직접 켜서 한 화면에 모두(S24).
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
  testWidgets('탑다운 표시 골든 s24', (tester) async {
    const dpr = 2.8125;
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const box = Size(384, 832 - 48 - 24 - 76);
    final scene = BattleScene(tables, topRecording(tables, ticks: 160), loop: false)..layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(scene)..sprites = bank;
    final frame = topFrameFor(box, dpr);
    final warm = Canvas(PictureRecorder());
    while (scene.player.position < 60) {
      scene.update(kFrameMs);
      painter.paintTop(warm, frame);
    }
    expect(scene.poseCount, greaterThanOrEqualTo(4), reason: '표시를 얹을 적');
    for (var k = 0; k < scene.poseCount; k++) {
      final e = scene.poses[k]..flash = false;
      switch (k % 4) {
        case 0:
          e
            ..tier = 2
            ..shielded = true;
        case 1:
          e
            ..stunned = true
            ..burning = true;
        case 2:
          e
            ..slowed = true
            ..vulnerable = true;
        case _:
          e.tier = 1;
      }
    }
    final ship = scene.topShip;
    scene.zones.obtain()
      ..x = ship.dx - 50
      ..y = ship.dy - 70
      ..radius = 22;
    scene.chest
      ..visible = true
      ..x = ship.dx + 45
      ..y = ship.dy + 30
      ..sink = 0;
    scene.shipBuffMs = 500;
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_marks_s24.png'));
  });
}

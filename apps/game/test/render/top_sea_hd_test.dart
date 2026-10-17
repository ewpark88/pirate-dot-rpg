import 'dart:ui' as ui;

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

/// HD 해역 바다 디테일(S1 '손맛 배경 한 단계'): 해역 6곳(산호·폭풍·빙하·화산·심연·유령) 전투 장면을 작게 나란히 — 빛 일렁임·
/// 반짝임 + 해역별(분홍 거품·바람결·얼음 조각·불티·빛줄기와 발광 점·초록 안개).
void main() {
  testWidgets('HD 해역 바다 6곳', (tester) async {
    const dpr = 1.0;
    const box = Size(240, 420);
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const stages = [12, 62, 112, 162, 212, 262];
    final painters = <(ScenePainter, TopFrame)>[];
    for (final st in stages) {
      final scene = BattleScene(tables, topRecording(tables, ticks: 120, stage: st), loop: false)
        ..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = ui.Canvas(ui.PictureRecorder());
      while (scene.player.position < 100) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      painters.add((painter, frame));
    }
    final size = Size(box.width * stages.length, box.height);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(painter: _Row(painters, box)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_sea_hd.png'));
  });
}

class _Row extends CustomPainter {
  _Row(this.painters, this.box);
  final List<(ScenePainter, TopFrame)> painters;
  final Size box;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (i, (p, f)) in painters.indexed) {
      canvas
        ..save()
        ..translate(i * box.width, 0)
        ..clipRect(Offset.zero & box);
      p.paintTop(canvas, f);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

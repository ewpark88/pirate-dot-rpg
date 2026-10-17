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

import 'helpers.dart';
import 'top_recording.dart';

/// 2배속 '질풍'(S1 '속도 ×2 효과가 밋밋'): 꺼짐 | 켜는 순간(0.3초 — 양옆 바람결 휙·배 뒤 물보라) | 켜진 동안(2초 — 양옆 바람 줄·돛 부풂·흐름 빠르게) 한 장.
void main() {
  testWidgets('2배속 질풍 시안', (tester) async {
    const dpr = 1.5;
    const box = Size(300, 520);
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final base = topRecording(tables, ticks: 260, stage: 20);
    List<RecordedTick> rec(int onAt) => [
      for (final (i, t) in base.indexed)
        RecordedTick(BattleView.fromJson({...t.frame.toJson(), 'speed': i >= onAt ? 2 : 1}), t.events),
    ];
    final shots = <(ScenePainter, TopFrame)>[];
    for (final (onAt, afterMs) in const [(9999, 0.0), (100, 300.0), (100, 2000.0)]) {
      final scene = BattleScene(tables, rec(onAt), loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = ui.Canvas(ui.PictureRecorder());
      while (scene.player.position < 100) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      for (var ms = 0.0; ms < afterMs; ms += kFrameMs) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      shots.add((painter, frame));
    }
    final size = Size(box.width * 3, box.height);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(painter: _Row(shots, box)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_gale.png'));
  });
}

class _Row extends CustomPainter {
  _Row(this.shots, this.box);
  final List<(ScenePainter, TopFrame)> shots;
  final Size box;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (i, (p, f)) in shots.indexed) {
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

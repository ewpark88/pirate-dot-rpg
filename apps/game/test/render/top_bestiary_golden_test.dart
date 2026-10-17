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

/// 도감 v2 보스 패턴(InkCloud·BossSwallowed·BossSplit): 먹물 얼룩·빨려 드는 적과 초록 고리·끈적한 분열 띠. 실제 보스 + 주입, S24.
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
  for (final (name, after) in const [('ink', 600.0), ('swallow', 420.0), ('split', 220.0)]) {
    testWidgets('도감 v2 보스 패턴 골든 s24 $name', (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      final base = topRecording(tables, ticks: 320, stage: 120, bossAt: 5);
      final at = base.indexWhere((t) => t.frame.enemies.any((e) => e.boss), 160);
      final f = base[at].frame;
      final boss = f.enemies.firstWhere((e) => e.boss);
      final near =
          [
            for (final e in f.enemies)
              if (!e.boss) e,
          ]..sort(
            (a, b) =>
                ((a.x - boss.x).abs() + (a.y - boss.y).abs()).compareTo((b.x - boss.x).abs() + (b.y - boss.y).abs()),
          );
      final ev = switch (name) {
        'ink' => InkCloud(
          f.tick,
          enemyId: boss.id,
          x: (f.shipX ?? 135) - 10,
          y: (f.shipY ?? 240) - 60,
          radius: 40,
          ticks: 50,
        ),
        'swallow' => BossSwallowed(
          f.tick,
          enemyId: boss.id,
          eaten: [for (final e in near.take(3)) e.id],
          healed: BigNum.from(5000),
        ),
        _ => BossSplit(f.tick, parentId: boss.id, childId: 9999, x: boss.x + 40, y: boss.y + 10),
      };
      final rec = [
        for (var i = 0; i < base.length; i++) i == at ? RecordedTick(base[i].frame, [...base[i].events, ev]) : base[i],
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_bestiary_${name}_s24.png'));
    });
  }
}

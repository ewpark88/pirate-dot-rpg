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

/// 보스 특성(S2 boss-traits): 반사막 육각·분노 붉은 오라+눈 빛+커짐·호위 고리·회피 잔상. 실제 보스 + 주입, S24.
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
  for (final (name, after) in const [('reflect', 900.0), ('enrage', 300.0), ('evade', 150.0)]) {
    testWidgets('보스 특성 골든 s24 $name', (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      final base = topRecording(tables, ticks: 320, stage: 120, bossAt: 5);
      final at = base.indexWhere((t) => t.frame.enemies.any((e) => e.boss), 160);
      final f = base[at].frame;
      final boss = f.enemies.firstWhere((e) => e.boss);
      final evs = switch (name) {
        'reflect' => [BossTraitFired(f.tick, enemyId: boss.id, trait: 'reflect', ticks: 80)],
        'enrage' => [
          BossTraitFired(f.tick, enemyId: boss.id, trait: 'enrage'),
          BossTraitFired(f.tick, enemyId: boss.id, trait: 'escort'),
        ],
        _ => [AttackMissed(f.tick, crewId: 'octo', x: boss.x, y: boss.y, reason: 'evade')],
      };
      final rec = [
        for (var i = 0; i < base.length; i++)
          i == at ? RecordedTick(base[i].frame, [...base[i].events, ...evs]) : base[i],
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
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('goldens/top_boss_trait_${name}_s24.png'),
      );
    });
  }
}

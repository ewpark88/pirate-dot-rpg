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

/// 범위 임팩트 v2 (사용자 '모레이 같은 범위 스킬 임팩트가 허접하다', S1): 계열마다 선원 하나만 태운 실제 기록에서
/// 첫 범위 피해(AoeDamageSum) 0.12초 뒤 — 흰 코어·등급 색 고리 2겹·파편(수중은 물기둥·거품)·잔흔. S24.
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
  const crews = {'lob': 'octo', 'underwater': 'moray', 'shock': 'turtle', 'air': 'polly'};
  for (final MapEntry(key: family, value: crew) in crews.entries) {
    testWidgets('범위 임팩트 골든 s24 $family', (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      final rec = topRecording(tables, ticks: 400, levels: {crew: 52});
      final at = rec.indexWhere((t) => t.events.any((e) => e is AoeDamageSum));
      expect(at, greaterThan(0), reason: '$crew($family) 범위 피해');
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      final stop = at + 0.12 * 1000 / tables.waves.tickMs;
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_impact_${family}_s24.png'));
    });
  }
}

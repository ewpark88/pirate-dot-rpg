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

/// 선원 개성 v2 연출 (S5 crew-identity, S1): 거북 보호막(육각 껍질), 펠리 낙뢰 예고·내리꽂힘(연쇄), 실제 기록(거북·펠리·펌펌 신화).
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
  final rec = topRecording(tables, ticks: 600, stage: 60, levels: const {'turtle': 66, 'pelly': 66, 'pumpum': 66});
  int first(bool Function(GameEvent e) f) => rec.indexWhere((t) => t.events.any(f));
  final cases = {
    'shield': (first((e) => e is ShieldUp), 0.4),
    'bolt_warn': (first((e) => e is AttackFired && e.kind == 'lightning'), 0.2),
    'bolt_strike': (first((e) => e is AttackFired && e.kind == 'lightning'), 0.5),
  };
  for (final MapEntry(key: name, value: (at, after)) in cases.entries) {
    testWidgets('개성 v2 골든 s24 $name', (tester) async {
      expect(at, greaterThanOrEqualTo(0), reason: '$name 이벤트가 기록에 있어야 한다');
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      final stop = at + after * 1000 / tables.waves.tickMs;
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_crew_${name}_s24.png'));
    });
  }
}

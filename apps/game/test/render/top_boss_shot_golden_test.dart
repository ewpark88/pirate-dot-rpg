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

/// 보스 포탄 (사용자 '보스가 폭탄도 안 쏜다', S1·S5): 엔진 BossFired를 비행 시간만큼 앞서 띄워 피해 시각에 배에 닿는다.
/// 크고 어두운 포탄 + 보스 색 빛 테·불 꼬리, 닿으면 폭발. 실제 기록(보스 소환)에서 첫 보스 발사 0.3초 전·닿은 직후(S24).: 때린 적이 배 쪽으로 툭 박고(돌진 120ms),
/// 닿은 자리에 물보라·나뭇조각, 배 번쩍·미세 흔들림, 배 위 작은 빨간 피해 숫자. 실제 엔진 기록의 첫 배 피격 60ms 뒤(S24).
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
  for (final (name, back) in const [('flight', 0.3), ('impact', -0.08)]) {
    testWidgets('보스 포탄 골든 s24 $name', (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      final rec = topRecording(tables, ticks: 700, stage: 60, bossAt: 5);
      final at = rec.indexWhere((t) => t.events.any((e) => e is BossFired));
      expect(at, greaterThan(0), reason: '기록에 보스 발사가 있어야 한다');
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      final stop = at - back * 1000 / tables.waves.tickMs;
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_boss_shot_${name}_s24.png'));
    });
  }
}

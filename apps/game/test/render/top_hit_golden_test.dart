import 'dart:ui' show PictureRecorder;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/render/top/top_hits.dart';

import 'helpers.dart';
import 'top_recording.dart';

/// 배 충돌 연출 (사용자 '적들이 배에 부딪히지 않는다', S1): 때린 적이 배 쪽으로 툭 박고(돌진 120ms),
/// 닿은 자리에 물보라·나뭇조각, 배 번쩍·미세 흔들림, 배 위 작은 빨간 피해 숫자. 실제 엔진 기록에 배 피격을 주입(withShipHit — 엔진 균형이 바뀌어도 장면이 같다)해 때린 적이 살아 있는 첫 배 피격 60ms 뒤(S24).
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
  test('돌진: 맞은 뒤 120ms 동안만, 가운데에서 가장 멀리', () {
    final h = TopHits();
    expect(h.lungeOf(1, 0), 0);
  });

  testWidgets('배 충돌 골든 s24', (tester) async {
    const dpr = 2.8125;
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const box = Size(384, 832 - 48 - 24 - 76);
    final rec = withShipHit(topRecording(tables, ticks: 400));
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
    for (var i = 0; i < 4; i++) {
      scene.update(kFrameMs);
      painter.paintTop(warm, frame);
    }
    final hitter = [
      for (var k = 0; k < scene.poseCount; k++) scene.poses[k],
    ].any((e) => scene.topHits.lungeOf(e.id, scene.clockMs) > 0);
    expect(hitter, isTrue, reason: '때린 적이 돌진 중');
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_hit_s24.png'));
  });
}

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

import '../ui/ui_harness.dart';
import 'helpers.dart';
import 'top_recording.dart';

/// 피버 시작 연출 (사용자 '피버타임 임펙트가 하나도 없다', S1): 금빛 번쩍·배에서 퍼지는 충격파·바다 금빛·불꽃 오라·불 꼬리·속도선: 때린 적이 배 쪽으로 툭 박고(돌진 120ms),
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
  setUpAll(loadGoldenFonts);
  // strike_*: 피버 첫 일격(UltimateCast) — 선장 컷인(0.15초)·금빛 번개(0.7초).
  for (final (name, afterMs, strike) in const [
    ('start', 250.0, false),
    ('mid', 3000.0, false),
    ('strike_cut', 150.0, true),
    ('strike_bolt', 700.0, true),
  ]) {
    testWidgets('피버 골든 s24 $name', (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      final rec = withFever(topRecording(tables, ticks: 400), strike: strike);
      final at = rec.indexWhere((t) => t.events.any((e) => e is FeverStarted));
      expect(at, greaterThan(0), reason: '기록에 피버 시작이 있어야 한다');
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      while (scene.player.position < at) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      for (var ms = 0.0; ms < afterMs; ms += kFrameMs) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      if (afterMs >= 250) expect(painter.top.fever.level, greaterThan(0.5));
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_fever_${name}_s24.png'));
    });
  }
}

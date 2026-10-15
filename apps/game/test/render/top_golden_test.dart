import 'dart:ui' show PictureRecorder;

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

/// 탑다운 골든 (T2): T1 엔진 실제 기록(stage 31)을 틱 138까지 — 배 가운데·바다·적(방향)·투척 그림자·숫자·HUD·선원 줄.
/// 상자 = 화면 − 상단 바 48 − 상태 줄 24 − 도크 76 (전체 화면 전투, 시트 닫힘). 물리 픽셀로 찍는다.
const _devices = {
  '360x640': (Size(360, 640), 3.0),
  's24': (Size(384, 832), 2.8125),
  '411x891': (Size(411, 891), 2.625),
  'tablet800x1280': (Size(800, 1280), 2.0),
};

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
  final rec = topRecording(tables, ticks: 160);
  for (final MapEntry(key: name, value: (screen, dpr)) in _devices.entries) {
    testWidgets('탑다운 골든 $name', (tester) async {
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      final box = Size(screen.width, screen.height - 48 - 24 - 76);
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder()); // 매 프레임 그려야 바다 흐름·체력 막대 같은 그리기 상태가 실제와 같다.
      while (scene.player.position < 138) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      final pw = (box.width * dpr).roundToDouble();
      final ph = (box.height * dpr).roundToDouble();
      tester.view
        ..physicalSize = Size(pw, ph)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: pw,
              height: ph,
              child: CustomPaint(painter: _Painter(painter, frame, dpr)),
            ),
          ),
        ),
      );
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_$name.png'));
    });
  }
}

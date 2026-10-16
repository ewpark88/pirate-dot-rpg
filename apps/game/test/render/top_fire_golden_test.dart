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

/// 발사 임팩트·등급 꼬리 (사용자 '폭탄을 쏠 때 임팩트가 없다 — 영웅부터 등급 색 꼬리', S1):
/// 선원 등급 = 레벨 띠(희귀 20·영웅 40·전설 52·신화 66). 포구 섬광(등급 색 테)·연기·고리 + 영웅 보라 잔상·전설 금빛 별 가루·신화 무지개 + 빛 고리.: 때린 적이 배 쪽으로 툭 박고(돌진 120ms),
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
  testWidgets('발사 골든 s24 (등급별 꼬리)', (tester) async {
    const dpr = 2.8125;
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const box = Size(384, 832 - 48 - 24 - 76);
    final rec = topRecording(tables, ticks: 200, levels: const {'octo': 40, 'pang': 52, 'sword': 66, 'turtle': 20});
    final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(scene)..sprites = bank;
    final frame = topFrameFor(box, dpr);
    final warm = Canvas(PictureRecorder());
    while (scene.player.position < 70) {
      scene.update(kFrameMs);
      painter.paintTop(warm, frame);
    }
    expect(scene.projectiles.active, isNotEmpty);
    expect({for (final s in scene.frame.fleet) s.rarity}, containsAll(<int>[1, 2, 3, 4]), reason: '희귀·영웅·전설·신화');
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_fire_s24.png'));
  });
}

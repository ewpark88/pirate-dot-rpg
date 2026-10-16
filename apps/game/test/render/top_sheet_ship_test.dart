import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import 'helpers.dart';
import 'top_recording.dart';

/// 시트를 열어 전장 상자가 짧아진 뒤 시계가 안 가도(전투 멈춤·한 번만 다시 그리기) 배는 바로 새 자리 — 선원 줄 밑에 숨지 않는다(S5 스토어 03_ship).
void main() {
  testWidgets('상자가 짧아지면 시계가 멈춰 있어도 배가 선원 줄 위 새 자리', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const dpr = 2.625;
    final scene = BattleScene(tables, topRecording(tables, ticks: 40), loop: false)
      ..layout = battleFrameFor(const Size(411, 760), dpr);
    final painter = ScenePainter(scene)..sprites = bank;
    final tall = topFrameFor(const Size(411, 760), dpr);
    for (var i = 0; i < 30; i++) {
      scene.update(kFrameMs);
      painter.paintTop(Canvas(PictureRecorder()), tall);
    }
    final short = topFrameFor(const Size(411, 341), dpr);
    painter.paintTop(Canvas(PictureRecorder()), short);
    expect(painter.top.drawnShipY, closeTo(short.shipScreen.dy, 0.01));
    expect(painter.top.drawnShipY, lessThan(short.band.slotBand.top));
  });
}

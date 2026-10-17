import 'dart:ui' show PictureRecorder;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/text/outline_digits.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import '../ui/ui_harness.dart';
import 'helpers.dart';
import 'top_recording.dart';

/// 심연의 탑(S1): 층 시작 띠 '12F'(보라 띠·금 테·CLEAR!) + 심연 바다 팔레트. S24.
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
  testWidgets('심연의 탑 층 띠 골든 s24', (tester) async {
    const dpr = 2.8125;
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final digits = (await tester.runAsync(() => OutlineDigits.load(devicePixelRatio: dpr)))!;
    const box = Size(384, 832 - 48 - 24 - 76);
    final base = topRecording(tables, ticks: 260, stage: 40);
    final rec = [
      for (final (i, t) in base.indexed)
        RecordedTick(
          t.frame.copyWith(tower: const TowerView(floor: 12, wave: 1, waves: 3)),
          i == 180 ? [...t.events, TowerFloorCleared(i, floor: 11)] : t.events,
        ),
    ];
    final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(scene)
      ..sprites = bank
      ..digits = digits;
    final frame = topFrameFor(box, dpr);
    final warm = Canvas(PictureRecorder());
    while (scene.player.position < 186) {
      scene.update(kFrameMs);
      painter.paintTop(warm, frame);
    }
    expect(scene.moments.bannerText, '12F');
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_tower_s24.png'));
  });

  // 회귀(사용자 '이펙트가 조잡하고 배가 보이지도 않는다' — 탑 1층 2/3파 캡처): 적이 배에 붙어 칼질·착탄·금화가 몰려도
  // 배가 맨 위 층으로 또렷이 보이고, 심연 바다가 너무 어둡지 않다.
  testWidgets('심연의 탑 붐빔 — 배가 보인다 s24', (tester) async {
    const dpr = 2.8125;
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final digits = (await tester.runAsync(() => OutlineDigits.load(devicePixelRatio: dpr)))!;
    const box = Size(384, 832 - 48 - 24 - 76);
    final base = topRecording(tables, ticks: 320, stage: 12);
    final rec = [
      for (final t in base)
        RecordedTick(t.frame.copyWith(tower: const TowerView(floor: 1, wave: 2, waves: 3)), t.events),
    ];
    final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(scene)
      ..sprites = bank
      ..digits = digits;
    final frame = topFrameFor(box, dpr);
    final warm = Canvas(PictureRecorder());
    while (scene.player.position < 300) {
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_tower_crowd_s24.png'));
  });
}

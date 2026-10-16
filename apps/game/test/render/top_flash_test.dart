import 'dart:ui' as ui;

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

/// 눈부심 회귀 (사용자 '흰 번쩍임이 너무 많아 눈이 아프다', WCAG 2.3.1 참고): 전원 신화 + 피버 시작 + 빠른 항해 rush·피날레 장면을
/// 작게 그려 프레임마다 평균 밝기를 잰다 — 이웃 프레임 변화 20% 이하, 10% 넘는 변화는 초당 3번 이하.
void main() {
  testWidgets('화면 밝기 변화가 작고 드물다(번쩍임 회귀)', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const box = Size(192, 342);
    final rec = withFastSail(
      withFever(
        topRecording(
          tables,
          ticks: 400,
          levels: const {'octo': 66, 'pang': 66, 'moray': 66, 'turtle': 66, 'pelly': 66, 'polly': 66},
        ),
        at: 40,
      ),
    );
    final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, 1);
    final painter = ScenePainter(scene)..sprites = bank;
    final frame = topFrameFor(box, 1);
    while (scene.player.position < 36) {
      scene.update(kFrameMs);
      painter.paintTop(Canvas(ui.PictureRecorder()), frame);
    }
    final lum = <double>[];
    const frames = 360; // 6초 — 피버 시작·돌파 시작·rush·피날레
    for (var f = 0; f < frames; f++) {
      scene.update(kFrameMs);
      final r = ui.PictureRecorder();
      painter.paintTop(Canvas(r), frame);
      final img = await tester.runAsync(() => r.endRecording().toImage(box.width.toInt(), box.height.toInt()));
      final data = (await tester.runAsync(() => img!.toByteData()))!;
      final px = data.buffer.asUint8List();
      var sum = 0.0;
      for (var i = 0; i < px.length; i += 4 * 7) {
        sum += 0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2];
      }
      lum.add(sum / (px.length / (4 * 7)) / 255);
    }
    var maxJump = 0.0;
    var bigJumps = 0;
    for (var i = 1; i < lum.length; i++) {
      final d = (lum[i] - lum[i - 1]).abs() / lum[i - 1].clamp(0.05, 1);
      if (d > maxJump) maxJump = d;
      if (d > 0.1) bigJumps++;
    }
    // 결과를 로그에 남겨 기준 여유를 본다.
    // ignore: avoid_print
    print('밝기 변화: 최대 ${(maxJump * 100).toStringAsFixed(1)}%, 10% 넘는 변화 $bigJumps번 / ${frames / 60}초');
    expect(maxJump, lessThanOrEqualTo(0.2));
    expect(bigJumps / (frames / 60), lessThanOrEqualTo(3));
  });
}

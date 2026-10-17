import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import 'helpers.dart';
import 'top_recording.dart';

/// 보스 피격 반응(S1 '보스전 밋밋'): 체력 층을 넘을 때마다 '부서짐' — 조각 터짐·흔들림. 칸 안에서는 안 터진다.
void main() {
  testWidgets('보스 체력 층이 깨질 때마다 부서짐', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final base = topRecording(tables, ticks: 200, stage: 120, bossAt: 5);
    // 보스 체력을 틱 60에 0.8, 100에 0.6(3층 → 2층)으로
    double hp(int i) => i < 60 ? 1.0 : (i < 100 ? 0.8 : 0.6); // 3층: 1.0·0.8은 3층, 0.6은 2층
    final rec = [
      for (final (i, t) in base.indexed)
        RecordedTick(
          BattleView.fromJson({
            ...t.frame.toJson(),
            'enemies': [
              for (final e in t.frame.enemies) {...e.toJson(), if (e.boss) 'hpRatio': hp(i)},
            ],
          }),
          t.events,
        ),
    ];
    const box = ui.Size(384, 684);
    final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, 2.8125);
    final painter = ScenePainter(scene)..sprites = bank;
    final frame = topFrameFor(box, 2.8125);
    final canvas = ui.Canvas(ui.PictureRecorder());
    var burstAt = -1.0;
    var burstBefore = false;
    while (scene.player.position < 180) {
      scene.update(kFrameMs);
      painter.paintTop(canvas, frame);
      final active = scene.topHits.shatter.active;
      if (active && burstAt < 0) burstAt = scene.player.position;
      if (active && scene.player.position < 99) burstBefore = true;
    }
    expect(burstBefore, isFalse, reason: '같은 층 안에서는 안 부서진다');
    expect(burstAt, inInclusiveRange(99, 104), reason: '층을 넘는 틱에 부서진다');
  });
}

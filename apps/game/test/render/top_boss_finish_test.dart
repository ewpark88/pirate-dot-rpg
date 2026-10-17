import 'dart:ui' as ui;

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

/// 보스 처치 피니시(S1): 마지막 타격 순간 슬로·줌 펀치·흰 번쩍·큰 조각·금화 폭포 + 'BOSS DOWN!'(대보스 금빛 'VICTORY!').
void main() {
  setUpAll(loadGoldenFonts);
  test('대보스는 금빛 VICTORY!, 보통 보스는 BOSS DOWN!', () {
    final m = BattleScene(tables, null).moments..onBossDown(big: true);
    expect((m.bannerText, m.bannerGold), ('VICTORY!', true));
    m.onBossDown(big: false);
    expect((m.bannerText, m.bannerGold), ('BOSS DOWN!', false));
  });

  testWidgets('보스 처치 피니시 시안(처치 0.3초 뒤)', (tester) async {
    const dpr = 1.5;
    const box = Size(300, 520);
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final rec = topRecording(noHordeTables, ticks: 260, stage: 20, bossAt: 5);
    final kill = rec.indexWhere((t) => t.events.any((e) => e is BossCleared));
    expect(kill, greaterThan(0), reason: '기록 안에 보스 처치가 있어야 한다');
    final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(scene)..sprites = bank;
    final frame = topFrameFor(box, dpr);
    final warm = ui.Canvas(ui.PictureRecorder());
    while (scene.player.position < kill) {
      scene.update(kFrameMs);
      painter.paintTop(warm, frame);
    }
    for (var ms = 0.0; ms < 300; ms += kFrameMs) {
      scene.update(kFrameMs);
      painter.paintTop(warm, frame);
    }
    tester.view
      ..physicalSize = box
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: box,
            child: CustomPaint(painter: _One(painter, frame)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_boss_finish.png'));
  });
}

class _One extends CustomPainter {
  _One(this.p, this.f);
  final ScenePainter p;
  final TopFrame f;

  @override
  void paint(Canvas canvas, Size size) => p.paintTop(canvas, f);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

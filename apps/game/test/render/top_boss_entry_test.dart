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

/// 보스 등장 연출(S1): 바다 밑에서 솟음·물보라·0.3초 어둡게, 대보스는 1.2초 WARNING 붉은 띠·포효, 순환 보스 0.6초.
void main() {
  setUpAll(loadGoldenFonts);
  test('대보스 1.2초 WARNING, 순환 보스 0.6초·띠 없음', () {
    final m = BattleScene(tables, null).moments..onBossSpawned('ice_slime', 120);
    expect((m.entryTotal, m.bannerText, m.bannerHot), (1200, 'WARNING', true));
    final n = BattleScene(tables, null).moments..onBossSpawned('coral_golem', 12);
    expect((n.entryTotal, n.bannerMs > 0), (600, false));
  });

  testWidgets('보스 등장 시안(대보스 0.2초 | 0.7초)', (tester) async {
    const dpr = 1.5;
    const box = Size(300, 520);
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final rec = topRecording(noHordeTables, ticks: 200, stage: 120, bossAt: 5); // 대군 습격 띠 없이(WARNING만)
    final at = rec.indexWhere((t) => t.events.any((e) => e is BossSpawned));
    final shots = <(ScenePainter, TopFrame)>[];
    for (final after in const [200.0, 700.0]) {
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = ui.Canvas(ui.PictureRecorder());
      while (scene.player.position < at) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      for (var ms = 0.0; ms < after; ms += kFrameMs) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      shots.add((painter, frame));
    }
    final size = Size(box.width * 2, box.height);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(painter: _Row(shots, box)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_boss_entry.png'));
  });
}

class _Row extends CustomPainter {
  _Row(this.shots, this.box);
  final List<(ScenePainter, TopFrame)> shots;
  final Size box;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (i, (p, f)) in shots.indexed) {
      canvas
        ..save()
        ..translate(i * box.width, 0)
        ..clipRect(Offset.zero & box);
      p.paintTop(canvas, f);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

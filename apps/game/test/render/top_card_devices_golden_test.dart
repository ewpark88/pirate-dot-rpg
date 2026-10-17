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

/// #22 카드 앞면 공개 4기기(360·S24·411·태블릿) — 보스 처치 보상 터짐 (사용자 피드백 #18 '보스 처치 보상이 확실히 보이게'): 보스 자리 연쇄 폭발·빛줄기·충격파 →
/// 금화·젬이 크게 튀어나와 떠 있다가 → 배로 빨려 들어간다. 실제 엔진 보스 + 처치 주입(withBossKill), S24.
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

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640 - 148), 3.0),
  ('411', Size(411, 891 - 148), 2.625),
  ('tablet', Size(800, 1280 - 148), 2.0),
];

void main() {
  setUpAll(loadGoldenFonts);
  for (final (name, box, dpr) in _devices) {
    testWidgets('카드 앞면 공개 골든 $name', (tester) async {
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      final base = topRecording(tables, ticks: 300, stage: 120, bossAt: 5);
      final at = base.indexWhere((t) => t.frame.enemies.any((e) => e.boss), 120);
      final rec = withBossKill(
        base,
        at: at,
        cards: [
          (t) => CardGranted(t, crewId: 'pang', rarity: 'common', source: 'boss'),
          (t) => CardGranted(t, crewId: 'moray', rarity: 'hero', source: 'boss', isNew: true),
          (t) => CardGranted(t, crewId: 'turtle', rarity: 'legend', source: 'boss'),
        ],
      );
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      scene.topHits.loot.crewName = (id) => const {'moray': '모레이', 'turtle': '거북 선장'}[id] ?? id;
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      while (scene.player.position < at + 1) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      final start = scene.clockMs;
      while (scene.clockMs - start < 1500) {
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_card_reveal_$name.png'));
    });
  }
}

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

/// 보스 처치 보상 터짐 (사용자 피드백 #18 '보스 처치 보상이 확실히 보이게'): 보스 자리 연쇄 폭발·빛줄기·충격파 →
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

void main() {
  setUpAll(loadGoldenFonts);
  for (final (name, ms, cards) in const [
    ('blast', 180.0, false),
    ('pop', 650.0, false),
    ('hold', 1100.0, false),
    ('fly', 1420.0, false),
    ('cards', 1500.0, true),
  ]) {
    testWidgets('보스 처치 보상 골든 s24 $name', (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      final base = topRecording(tables, ticks: 300, stage: 120, bossAt: 5);
      final at = base.indexWhere((t) => t.frame.enemies.any((e) => e.boss), 120);
      expect(at, greaterThan(0), reason: '기록에 보스가 있어야 한다');
      final rec = withBossKill(
        base,
        at: at,
        cards: [
          if (cards) (t) => CardGranted(t, crewId: 'pang', rarity: 'common', source: 'boss'),
          if (cards) (t) => CardGranted(t, crewId: 'moray', rarity: 'hero', source: 'boss', isNew: true),
        ],
      );
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      while (scene.player.position < at + 1) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      expect(scene.topHits.loot.active, isTrue, reason: '보스 처치에 보상 터짐이 켜져야 한다');
      final start = scene.clockMs;
      while (scene.clockMs - start < ms) {
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_boss_loot_${name}_s24.png'));
    });
  }

  // 첫 희귀 선원 환영(보스 없이 배 앞) · 현상금 소탕(한 틱 30장 → 같은 선원 ×n, 4장 + '+n', 새 동료는 따로 크게).
  for (final (name, cards) in [
    ('starter', [(int t) => CardGranted(t, crewId: 'bones', rarity: 'rare', source: 'starter', isNew: true)]),
    (
      'sweep',
      [
        for (var k = 0; k < 30; k++)
          (int t) => CardGranted(
            t,
            crewId: const ['pang', 'octo', 'sword', 'turtle', 'moray', 'pelly'][k % 6],
            rarity: k % 5 == 0 ? 'rare' : 'common',
            source: 'bounty',
          ),
        (int t) => CardGranted(t, crewId: 'bones', rarity: 'hero', source: 'bounty', isNew: true),
      ],
    ),
  ]) {
    testWidgets('카드 골든 s24 $name', (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      const at = 100;
      final rec = withCard(
        topRecording(tables, ticks: 200),
        at: at,
        cards: cards,
      );
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      while (scene.player.position < at + 1) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      final start = scene.clockMs;
      while (scene.clockMs - start < 1300) {
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_card_${name}_s24.png'));
    });
  }

  testWidgets('보물상자 대기 골든 s24 (피드백 #6 누르고 싶게 — 빛줄기·반사·들썩·별)', (tester) async {
    const dpr = 2.8125;
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const box = Size(384, 832 - 48 - 24 - 76);
    final rec = withChestOpen(topRecording(tables, ticks: 200), at: 190);
    final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
    final painter = ScenePainter(scene)..sprites = bank;
    final frame = topFrameFor(box, dpr);
    final warm = Canvas(PictureRecorder());
    // 상자가 뜬 뒤, 들썩이는 순간(1.8초 주기의 0.1초 지점)까지.
    while (scene.player.position < 165 || scene.clockMs % 1800 < 90 || scene.clockMs % 1800 > 140) {
      scene.update(kFrameMs);
      painter.paintTop(warm, frame);
    }
    expect(scene.chest.visible, isTrue);
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_chest_idle_s24.png'));
  });

  // 보물상자 열림·광고 보상(피드백 #15): 금빛 기둥 + 금화 분수 / 배에서 고리·별가루.
  for (final (name, ms, ad) in const [('chest', 500.0, false), ('ad', 350.0, true)]) {
    testWidgets('보상 임팩트 골든 s24 $name', (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      const at = 120;
      final rec = withChestOpen(topRecording(tables, ticks: 200), at: ad ? 60 : at, adAt: ad ? at : null);
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      while (scene.player.position < at + 1) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
      }
      final start = scene.clockMs;
      while (scene.clockMs - start < ms) {
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_reward_${name}_s24.png'));
    });
  }
}

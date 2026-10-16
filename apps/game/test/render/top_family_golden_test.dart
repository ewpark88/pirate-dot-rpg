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

import 'helpers.dart';
import 'top_recording.dart';

/// 계열 8종 탑다운 공격 전수 점검 (사용자 '가재가 공격을 안 한다?', S1): 계열마다 선원 하나만 태운 실제 기록에서
/// 첫 공격 순간 — 발사체 계열은 닿기 0.35초 전(날아가는 중), 강습은 피해 0.1초 뒤(휘두르기·베기 자국). S24.
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
  const crews = {
    'lob': 'octo',
    'direct': 'pang',
    'pierce': 'sword',
    'skip': 'otter',
    'underwater': 'puffer',
    'air': 'polly',
    'assault': 'lobster',
    'shock': 'turtle',
  };
  for (final MapEntry(key: family, value: crew) in crews.entries) {
    testWidgets('계열 골든 s24 $family', (tester) async {
      const dpr = 2.8125;
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      final rec = topRecording(tables, ticks: 300, levels: {crew: 30});
      final at = rec.indexWhere((t) => t.events.any((e) => e is AttackFired && e.crewId == crew));
      expect(at, greaterThan(0), reason: '$crew($family)가 쏘아야 한다');
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)..sprites = bank;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      final stop = at + (family == 'assault' ? 0.1 : -0.35) * 1000 / tables.waves.tickMs;
      while (scene.player.position < stop) {
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
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_family_${family}_s24.png'));
    });
  }
}

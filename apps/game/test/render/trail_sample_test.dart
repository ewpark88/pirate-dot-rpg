import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/paint/trail_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/motion.dart';

import 'helpers.dart';

/// 등급 꼬리 v2 견본 (사용자 '더 가늘고 길게 — 일반 흰 가는 선, 등급 순으로 색·길이'): 일반·희귀·영웅·전설·신화를 나란히,
/// 같은 폭탄 크기(8단위)로 오른쪽 위로 날아가는 순간. 단위 1 = 5px.
class _Sheet extends CustomPainter {
  _Sheet(this.scene) : trails = TrailPainter(scene);
  final BattleScene scene;
  final TrailPainter trails;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A7FCC))
      ..scale(5);
    final style = scene.fx.projectileFor('direct');
    for (var r = 0; r < 5; r++) {
      final p = Projectile()
        ..style = style
        ..family = 'direct'
        ..crewId = 'c$r'
        ..flat = true
        ..fromX = 4
        ..fromY = 22 + r * 24.0
        ..toX = 140
        ..toY = 2 + r * 24.0
        ..progress = 0.8;
      final (x, y) = positionAt(p, p.progress);
      p
        ..x = x
        ..y = y;
      trails.paint(canvas, p, 8);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = const Color(0xFF1E1A26));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  testWidgets('등급 꼬리 견본 골든', (tester) async {
    final scene = BattleScene(tables, [
      RecordedTick(
        BattleView(
          mode: 'top',
          shipHp: BigNum.from(1),
          shipHpMax: BigNum.from(1),
          fleet: [for (var r = 0; r < 5; r++) FleetSlot(crewId: 'c$r', rarity: r)],
        ),
        const [],
      ),
    ], loop: false)..update(16);
    tester.view
      ..physicalSize = const Size(720, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(width: 720, height: 640, child: CustomPaint(painter: _Sheet(scene))),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/trail_rarities.png'));
  });
}

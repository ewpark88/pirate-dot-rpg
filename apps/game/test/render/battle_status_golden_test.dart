import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

class _Painter extends CustomPainter {
  _Painter(this.painter);

  final ScenePainter painter;

  @override
  void paint(ui.Canvas canvas, Size size) => painter.paint(canvas);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 상태별 적 한 줄: 감속 · 화상 · 취약 · 기절 · 셋 다 · 감속(플레이스홀더 종류).
List<RecordedTick> _recording() {
  List<EnemyView> enemies() => const [
    EnemyView(id: 1, kind: 'crab', x: 110, y: 100, hpRatio: 0.8, slowed: true),
    EnemyView(id: 2, kind: 'jelly', x: 140, y: 100, hpRatio: 0.6, burning: true),
    EnemyView(id: 3, kind: 'urchin', x: 170, y: 100, hpRatio: 1, vulnerable: true),
    EnemyView(id: 4, kind: 'piranha', x: 200, y: 100, hpRatio: 1, stunned: true),
    EnemyView(id: 5, kind: 'puffer', x: 235, y: 100, hpRatio: 0.5, stunned: true, burning: true, vulnerable: true),
    EnemyView(id: 6, kind: 'lavacrab', x: 270, y: 100, hpRatio: 1, slowed: true, burning: true),
    EnemyView(id: 7, kind: 'gull', x: 180, y: 44, hpRatio: 1, layer: 'air', slowed: true, vulnerable: true),
  ];
  return [
    for (var t = 0; t < 6; t++)
      RecordedTick(
        BattleView(tick: t, shipHp: BigNum.from(60), shipHpMax: BigNum.from(60), enemies: enemies()),
        const [],
      ),
  ];
}

void main() {
  testWidgets('render-status 골든: 감속·화상·취약·기절 표시', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final scene = BattleScene(tables, _recording(), loop: false);
    for (var i = 0; i < 4; i++) {
      scene.update(kFrameMs);
    }
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: kLogicalWidth,
            height: kLogicalHeight,
            child: CustomPaint(painter: _Painter(ScenePainter(scene)..sprites = bank)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/battle_status.png'));
  });
}

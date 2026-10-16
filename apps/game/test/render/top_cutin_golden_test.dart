import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

class _Painter extends CustomPainter {
  _Painter(this.painter);

  final ScenePainter painter;

  @override
  void paint(ui.Canvas canvas, Size size) => paintTopStd(painter, canvas);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 산호초 해역 보스(stage 50) 첫 등장: 컷인 띠가 머무는 순간 (render-moments 수용 기준 6).
void main() {
  testWidgets('render-moments 골든: 해역 보스 첫 등장 컷인', (tester) async {
    final boss = tables.regions.regionAt(50).regionBoss;
    List<EnemyView> enemies(int t, {required bool withBoss}) => [
      if (withBoss) EnemyView(id: 99, kind: boss, x: 300 - t * 1.0, y: 100, hpRatio: 1, boss: true),
      EnemyView(id: 1, kind: 'crab', x: 200 - t * 2.0, y: 100, hpRatio: 1),
      EnemyView(id: 2, kind: 'piranha', x: 230 - t * 3.0, y: 94, hpRatio: 1),
      EnemyView(id: 3, kind: 'gull', x: 215 - t * 2.0, y: 44, hpRatio: 1, layer: 'air'),
    ];
    RecordedTick tick(int t, List<GameEvent> events, {required bool withBoss}) => RecordedTick(
      BattleView(
        tick: t,
        shipHp: BigNum.from(60),
        shipHpMax: BigNum.from(60),
        bossActive: withBoss,
        enemies: enemies(t, withBoss: withBoss),
        stage: 50,
      ),
      events,
    );
    final scene = BattleScene(tables, [
      tick(0, const [], withBoss: false),
      tick(1, [BossSpawned(1, kind: boss, timeLimitTicks: 600)], withBoss: true),
      for (var t = 2; t < 40; t++) tick(t, const [], withBoss: true),
    ], loop: false);
    final cut = tables.fxMap.cutIn;
    final until = tickMs + cut.number('inMs') + cut.number('holdMs') / 2;
    var t = 0.0;
    while (t < until) {
      scene.update(kFrameMs);
      t += kFrameMs;
    }
    expect(scene.moments.cutIn.active, isTrue);

    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: kLogicalWidth,
            height: kLogicalHeight,
            child: CustomPaint(painter: _Painter(ScenePainter(scene))),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_cutin.png'));
  });
}

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/enemy_look.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

class _Painter extends CustomPainter {
  _Painter(this.painter);

  final ScenePainter painter;

  @override
  void paint(ui.Canvas canvas, Size size) => painter.paint(canvas);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 역할 표 고정 (regions.json 변경에 골든이 흔들리지 않게).
const _regions = '''
{"enemies": [
  {"id": "crab", "layer": "surface", "role": "basic"},
  {"id": "urchin", "layer": "surface", "role": "tough"},
  {"id": "flyingfish", "layer": "surface", "role": "fast"},
  {"id": "stormgull", "layer": "air", "role": "air"},
  {"id": "puffer", "layer": "underwater", "role": "basic"}
]}''';

const _fleet = [
  FleetSlot(crewId: 'octo', cooldown: 0.3, skillCooldown: 0.6),
  FleetSlot(crewId: 'pang', cooldown: 0.8),
];

/// 폭풍해(stage 75) 중간 보스 등장: 보호막 + tier 2, 무리, 떠 있는 보물상자.
List<RecordedTick> _recording() {
  List<EnemyView> enemies(int t, {required bool boss}) => [
    if (boss)
      EnemyView(
        id: 99,
        kind: 'storm_pirate',
        x: 290 - t * 1.0,
        y: 100,
        hpRatio: 1,
        boss: true,
        shielded: true,
        tier: 2,
      ),
    EnemyView(id: 1, kind: 'crab', x: 180 - t * 2.0, y: 100, hpRatio: 1),
    EnemyView(id: 2, kind: 'urchin', x: 200 - t * 1.0, y: 104, hpRatio: 0.6, tier: 1),
    EnemyView(id: 3, kind: 'flyingfish', x: 215 - t * 3.0, y: 94, hpRatio: 1),
    EnemyView(id: 4, kind: 'stormgull', x: 205 - t * 2.0, y: 44, hpRatio: 1, layer: 'air'),
    EnemyView(id: 5, kind: 'puffer', x: 230 - t * 2.0, y: 124, hpRatio: 1, layer: 'underwater', tier: 3),
  ];
  RecordedTick tick(int t, List<GameEvent> events, {required bool boss}) => RecordedTick(
    BattleView(
      tick: t,
      shipHp: BigNum.from(40),
      shipHpMax: BigNum.from(60),
      bossActive: boss,
      bossTicksLeft: boss ? 600 - t : 0,
      enemies: enemies(t, boss: boss),
      fleet: _fleet,
      captainId: 'octo',
      stage: 75,
      chest: ChestView(x: 120, y: 106, ticksLeft: 400 - t),
    ),
    events,
  );
  return [
    tick(0, const [], boss: false),
    tick(1, const [BossSpawned(1, kind: 'storm_pirate', timeLimitTicks: 600)], boss: true),
    for (var t = 2; t < 10; t++) tick(t, const [], boss: true),
  ];
}

void main() {
  testWidgets('render-regions 수용 기준 10: 폭풍해 중간 보스 등장 (보호막·tier 2·경고·보물상자)', (tester) async {
    final scene = BattleScene(
      tables,
      _recording(),
      loop: false,
      looks: EnemyLooks.fromRegionsJson(tables.fxMap, _regions),
    );
    var t = 0.0;
    while (t < 1.4 * tickMs) {
      scene.update(kFrameMs);
      t += kFrameMs;
    }
    expect(scene.bossWarnMs, greaterThan(0));
    expect(scene.chest.visible, isTrue);

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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/battle_boss_storm.png'));
  });
}

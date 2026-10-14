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

/// 역할 표를 고정한다 — regions.json이 바뀌어도 골든이 흔들리지 않게.
const _regions = '''
{"enemies": [
  {"id": "crab", "layer": "surface", "role": "basic"},
  {"id": "piranha", "layer": "surface", "role": "fast"},
  {"id": "lavacrab", "layer": "surface", "role": "tough"},
  {"id": "gull", "layer": "air", "role": "air"},
  {"id": "icecrab", "layer": "surface", "role": "split"},
  {"id": "icecrab_small", "layer": "surface", "role": "split"},
  {"id": "ghostjelly", "layer": "underwater", "role": "revive"}
]}''';

const _fleet = [
  FleetSlot(crewId: 'octo', cooldown: 0.5, skillCooldown: 0.25),
  FleetSlot(crewId: 'pang'),
  FleetSlot(crewId: 'starry', cooldown: 1, skillCooldown: 0.8),
];

/// 틱 0 해일 궁극기, 틱 1 수중 공격(장판), 틱 3 투척 스킬 + 분열 적 처치(작은 적 2마리).
List<RecordedTick> _recording() {
  EnemyView en(int id, String kind, double x, double y, {String layer = 'surface'}) =>
      EnemyView(id: id, kind: kind, x: x, y: y, hpRatio: 1, layer: layer);
  List<EnemyView> enemies(int t) => [
    en(1, 'crab', 170 - t * 2.0, 100),
    en(2, 'piranha', 190 - t * 3.0, 94),
    en(3, 'lavacrab', 215 - t * 1.0, 104),
    en(4, 'gull', 200 - t * 2.0, 44, layer: 'air'),
    en(5, 'ghostjelly', 230 - t * 2.0, 124, layer: 'underwater'),
    if (t < 3)
      en(10, 'icecrab', 250 - t * 2.0, 100)
    else ...[
      en(11, 'icecrab_small', 240 - (t - 3) * 2.0, 98),
      en(12, 'icecrab_small', 248 - (t - 3) * 2.0, 102),
    ],
  ];
  RecordedTick tick(int t, List<GameEvent> events) => RecordedTick(
    BattleView(
      tick: t,
      shipHp: BigNum.from(50),
      shipHpMax: BigNum.from(60),
      enemies: enemies(t),
      fleet: _fleet,
      captainId: 'octo',
    ),
    events,
  );
  return [
    tick(0, const [UltimateCast(0, crewId: 'octo', ultimateId: 'ult_tidal_wave')]),
    tick(1, const [
      AttackFired(1, crewId: 'starry', family: 'underwater', targetIds: [5], x: 228, y: 124),
    ]),
    tick(2, const []),
    tick(3, [
      const SkillCast(3, crewId: 'octo', skillId: 'lob_rain', x: 180, y: 100),
      Damage(3, targetId: 10, amount: BigNum.from(300), crewId: 'octo'),
      Kill(3, targetId: 10, gold: BigNum.from(20), x: 244, y: 100),
    ]),
    for (var t = 4; t < 8; t++) tick(t, const []),
  ];
}

void main() {
  testWidgets('render-m3 수용 기준 10: 스킬·궁극기 sweep·분열·장판·슬롯 덮개 둘', (tester) async {
    final scene = BattleScene(
      tables,
      _recording(),
      loop: false,
      looks: EnemyLooks.fromRegionsJson(tables.fxMap, _regions),
    );
    var t = 0.0;
    while (t < 3.4 * tickMs) {
      scene.update(kFrameMs);
      t += kFrameMs;
    }
    expect(scene.stats.splitPops, 1);
    expect(scene.zones.active, hasLength(1));

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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/battle_m3.png'));
  });
}

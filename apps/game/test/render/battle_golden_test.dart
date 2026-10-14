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
  void paint(ui.Canvas canvas, Size size) => painter.paint(canvas);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _fleet = [
  FleetSlot(crewId: 'octo', cooldown: 1),
  FleetSlot(crewId: 'turtle', cooldown: 0.4),
];

/// 고정 기록: 무리(물위 6·공중 2·물속 1)가 다가오고, 틱 4에 투척 폭탄이 3마리를 맞혀 2마리를 잡는다.
/// 샘플 기록(sample_battle.jsonl)은 전투 수치가 바뀔 때마다 다시 생성되므로 골든은 이 기록으로 찍는다.
List<RecordedTick> _recording() {
  List<EnemyView> enemies(int tick, {Set<int> dead = const {}}) => [
    for (var i = 0; i < 6; i++)
      if (!dead.contains(i + 1))
        EnemyView(id: i + 1, kind: i.isEven ? 'crab' : 'jelly', x: 200 + 14.0 * i - 2 * tick, y: 100, hpRatio: 1),
    EnemyView(id: 7, kind: 'gull', x: 220 - 2.0 * tick, y: 44, hpRatio: 0.5, layer: 'air'),
    EnemyView(id: 8, kind: 'gull', x: 250 - 2.0 * tick, y: 48, hpRatio: 1, layer: 'air'),
    EnemyView(id: 9, kind: 'fish', x: 240 - 2.0 * tick, y: 124, hpRatio: 1, layer: 'underwater'),
  ];
  RecordedTick tick(int t, List<GameEvent> events, {Set<int> dead = const {}}) => RecordedTick(
    BattleView(
      tick: t,
      shipHp: BigNum.from(45),
      shipHpMax: BigNum.from(60),
      enemies: enemies(t, dead: dead),
      fleet: _fleet,
      captainId: 'octo',
    ),
    events,
  );
  const hitTick = 4;
  const aimX = 214.0 - 2 * hitTick;
  return [
    for (var t = 0; t < hitTick; t++) tick(t, const []),
    tick(
      hitTick,
      [
        const AttackFired(hitTick, crewId: 'octo', family: 'lob', targetIds: [1, 2, 3], x: aimX, y: 100),
        Damage(hitTick, targetId: 1, amount: BigNum.from(120), crewId: 'octo'),
        Damage(hitTick, targetId: 2, amount: BigNum.from(360), crit: true, crewId: 'octo'),
        Damage(hitTick, targetId: 3, amount: BigNum.from(95), crewId: 'octo'),
        AoeDamageSum(hitTick, total: BigNum.from(575), x: aimX, y: 100),
        Kill(hitTick, targetId: 1, gold: BigNum.from(12), x: 200 - 2.0 * hitTick, y: 100),
        Kill(hitTick, targetId: 2, gold: BigNum.from(12), x: 214 - 2.0 * hitTick, y: 100),
      ],
      dead: const {1, 2},
    ),
    for (var t = hitTick + 1; t < hitTick + 4; t++) tick(t, const [], dead: const {1, 2}),
  ];
}

void main() {
  testWidgets('수용 기준 10: 범위 처치 직후 화면', (tester) async {
    final scene = BattleScene(tables, _recording(), loop: false);
    // 60fps 프레임으로 틱 4(범위 처치) + 0.4틱까지: 숫자·이펙트·코인·흔들림이 함께 보이는 순간.
    final targetMs = 4.4 * tickMs;
    var t = 0.0;
    while (t < targetMs) {
      scene.update(kFrameMs);
      t += kFrameMs;
    }
    expect(scene.numbers.active, isNotEmpty);
    expect(scene.coins.active, isNotEmpty);

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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/battle_aoe.png'));
  });
}

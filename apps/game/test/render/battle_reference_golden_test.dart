import 'dart:io';
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

const _fleet = [
  FleetSlot(crewId: 'octo', cooldown: 0.9),
  FleetSlot(crewId: 'bones', cooldown: 0.2),
  FleetSlot(crewId: 'sword', cooldown: 0.6),
  FleetSlot(crewId: 'pingu', cooldown: 0.4),
  FleetSlot(crewId: 'manta', cooldown: 0.75),
  FleetSlot(crewId: 'lamp', cooldown: 0.3),
];

const _kinds = ['crab', 'jelly', 'piranha', 'puffer', 'urchin', 'crab', 'piranha'];

/// 기준 battle_ship.gif 장면 재현 (render-quality-v1 수용 기준 1): stage 12, 무리 4덩이 + 갈매기, 틱 4에 투척 범위 처치(4마리 → 콤보).
List<RecordedTick> _recording() {
  final enemies = <(int, String, double, double, String)>[];
  var id = 1;
  for (var g = 0; g < 4; g++) {
    final gx = 150.0 + g * 45;
    final gy = 110.0 + (g * 7 % 20);
    for (var k = 0; k < 7; k++) {
      enemies.add((id++, _kinds[(g + k) % _kinds.length], gx + (k * 9 % 28) - 14, gy + (k * 5 % 22) - 8, 'surface'));
    }
  }
  enemies
    ..add((id++, 'gull', 260, 60, 'air'))
    ..add((id++, 'gull', 200, 52, 'air'));
  const killed = {1, 2, 3, 4};
  List<EnemyView> view(int t, {bool dead = false}) => [
    for (final (i, kind, x, y, layer) in enemies)
      if (!(dead && killed.contains(i))) EnemyView(id: i, kind: kind, x: x - t * 1.5, y: y, hpRatio: 1, layer: layer),
  ];
  RecordedTick tick(int t, List<GameEvent> events, {bool dead = false}) => RecordedTick(
    BattleView(
      tick: t,
      shipHp: BigNum.from(60),
      shipHpMax: BigNum.from(60),
      enemies: view(t, dead: dead),
      fleet: _fleet,
      captainId: 'octo',
      stage: 12,
      wave: 1,
      rage: 0.3,
      gold: BigNum.from(98),
    ),
    events,
  );
  return [
    tick(0, const []),
    tick(1, [
      const AttackFired(1, crewId: 'bones', family: 'direct', targetIds: [8], x: 186, y: 112),
      Damage(1, targetId: 8, amount: BigNum.from(18), crewId: 'bones'),
    ]),
    tick(2, [
      const AttackFired(2, crewId: 'manta', family: 'air', targetIds: [15, 22], x: 240, y: 120),
      Damage(2, targetId: 15, amount: BigNum.from(35), crewId: 'manta'),
      Damage(2, targetId: 22, amount: BigNum.from(35), crewId: 'manta'),
    ]),
    tick(3, const []),
    tick(4, [
      const AttackFired(4, crewId: 'octo', family: 'lob', targetIds: [1, 2, 3, 4], x: 144, y: 114),
      for (final i in killed) Damage(4, targetId: i, amount: BigNum.from(40), crewId: 'octo'),
      AoeDamageSum(4, total: BigNum.from(160), x: 144, y: 114),
      for (final (i, _, x, y, _) in enemies.where((e) => killed.contains(e.$1)))
        Kill(4, targetId: i, gold: BigNum.from(7), x: x - 6, y: y),
      const MultiKill(4, count: 4),
      Damage(4, targetId: 9, amount: BigNum.from(30), crit: true, crewId: 'bones'),
    ], dead: true),
    for (var t = 5; t < 12; t++) tick(t, const [], dead: true),
  ];
}

void main() {
  testWidgets('render-quality-v1 수용 기준 1: 기준 장면(battle_ship.gif) 재현', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final scene = BattleScene(tables, _recording(), loop: false);
    var t = 0.0;
    while (t < 4.3 * tickMs) {
      scene.update(kFrameMs);
      t += kFrameMs;
    }
    expect(scene.combo.count(scene.clockMs), greaterThanOrEqualTo(4));
    expect(scene.numbers.active, isNotEmpty);
    final painter = ScenePainter(scene)..sprites = bank;

    // 비교 이미지용 원본 PNG (`RENDER_DUMP=<폴더>`일 때만).
    final dump = Platform.environment['RENDER_DUMP'];
    if (dump != null) {
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        painter.paint(ui.Canvas(rec));
        final img = await rec.endRecording().toImage(kLogicalWidth.toInt(), kLogicalHeight.toInt());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dump/reference_ours.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: kLogicalWidth,
            height: kLogicalHeight,
            child: CustomPaint(painter: _Painter(painter)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/battle_reference.png'));
  });
}

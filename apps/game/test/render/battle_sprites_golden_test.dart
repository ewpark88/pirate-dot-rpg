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
  FleetSlot(crewId: 'octo', cooldown: 0.6, skillCooldown: 0.3),
  FleetSlot(crewId: 'pang', cooldown: 0.2),
  FleetSlot(crewId: 'starry', cooldown: 1, skillCooldown: 0.7),
];

/// 아트 팩 v0.2 스프라이트가 있는 종류만 쓴 고정 기록: 적 6종(물속 복어 포함), 보스선, 틱 4에 투척·직사 발사.
List<RecordedTick> _recording() {
  EnemyView en(int id, String kind, double x, double y, {String layer = 'surface', bool boss = false}) =>
      EnemyView(id: id, kind: kind, x: x, y: y, hpRatio: boss ? 0.7 : 1, layer: layer, boss: boss);
  List<EnemyView> enemies(int t) => [
    en(1, 'crab', 170 - t * 2.0, 100),
    en(2, 'piranha', 190 - t * 3.0, 94),
    en(3, 'jelly', 205 - t * 1.0, 104),
    en(4, 'urchin', 220 - t * 1.0, 98),
    en(5, 'gull', 200 - t * 2.0, 44, layer: 'air'),
    en(6, 'puffer', 235 - t * 2.0, 124, layer: 'underwater'),
    en(99, 'enemy_ship', 285 - t * 0.5, 96, boss: true),
  ];
  RecordedTick tick(int t, List<GameEvent> events) => RecordedTick(
    BattleView(
      tick: t,
      shipHp: BigNum.from(50),
      shipHpMax: BigNum.from(60),
      bossActive: true,
      enemies: enemies(t),
      fleet: _fleet,
      captainId: 'octo',
    ),
    events,
  );
  return [
    tick(0, const []),
    tick(1, [
      const AttackFired(1, crewId: 'octo', family: 'lob', targetIds: [1], x: 168, y: 100),
      Damage(1, targetId: 1, amount: BigNum.from(80), crewId: 'octo'),
      Kill(1, targetId: 9, gold: BigNum.from(5), x: 150, y: 100),
    ]),
    for (var t = 2; t < 4; t++) tick(t, const []),
    tick(4, const [
      AttackFired(4, crewId: 'octo', family: 'lob', targetIds: [3], x: 200, y: 104),
      AttackFired(4, crewId: 'pang', family: 'direct', targetIds: [2], x: 178, y: 94),
    ]),
    for (var t = 5; t < 10; t++) tick(t, const []),
  ];
}

void main() {
  testWidgets('render-art-pack 수용 기준 6: 아트 팩 스프라이트로 그린 장면', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    expect(bank['enemy:crab'], isNotNull, reason: 'pubspec assets 등록 후 실제 이미지를 읽어야 한다');
    expect(bank['crew:octo'], isNotNull);

    final scene = BattleScene(tables, _recording(), loop: false);
    var t = 0.0;
    while (t < 3.0 * tickMs) {
      scene.update(kFrameMs);
      t += kFrameMs;
    }
    expect(scene.projectiles.active, isNotEmpty, reason: '틱 4 발사체가 날아가는 중');

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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/battle_sprites.png'));
  });
}

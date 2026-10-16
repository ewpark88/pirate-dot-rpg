import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 계열 행동 v3 레이저(사용자 '직선 레이저 빔 0.3~0.6초, 관통 수가 등급별, 신화는 화면 끝까지').
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;

  GameTables laser(int pierce) {
    final raw = Map<String, String>.of(rawTables);
    final crews = jsonDecode(raw['crews']!) as Map<String, dynamic>;
    for (final c in (crews['crews'] as List).cast<Map<String, dynamic>>()) {
      if (c['id'] == 'nar') {
        c['aim'] = {
          'shape': 'laser',
          'laserPierce': pierce,
          'intervalSec': 30,
          'targets': 'nearest',
          'behavior': {'kind': 'laser', 'beamSec': 0.4},
        };
      }
    }
    raw['crews'] = jsonEncode(crews);
    return GameTables.load(raw);
  }

  List<GameEvent> fire(GameTables t) {
    final g = geometryFor(t, stage) as TopGeometry;
    final f = Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))
      ..geometry = g
      ..guns = [Gun.of(t, 'nar', power: 1)];
    for (var i = 0; i < 4; i++) {
      f.foes.add(
        Foe(
          id: i + 1,
          kind: 'crab',
          layer: 'surface',
          x: g.top.shipX,
          y: g.top.shipY - 40 - i * 20,
          maxHp: BigNum.from(1000000000000),
          speed: 0,
          attack: BigNum.zero,
          gold: BigNum.one,
        ),
      );
    }
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    final s = GameState.newGame(playerId: 'l', seed: 1, now: start);
    for (var i = 0; i < 20; i++) {
      ctx.tick = i;
      Round(f, ctx, CombatStats.of(s, t), rage: 0)
        ..fireGuns()
        ..topdownStep(s);
    }
    return events;
  }

  test('빔 0.4초(8틱) 유지: 매 틱 가까운 순 관통 수만큼, 한 발 피해를 틱으로 나눔, AttackFired.beamTicks', () {
    final ev = fire(laser(2));
    final fired = ev.whereType<AttackFired>().single;
    expect(fired.beamTicks, 8);
    expect(fired.flightTicks, isNull);
    final dmg = ev.whereType<Damage>().toList();
    expect(dmg.map((d) => d.targetId).toSet(), {1, 2}, reason: '관통 2');
    final perFoe = {
      for (final id in [1, 2]) id: dmg.where((d) => d.targetId == id).length,
    };
    expect(perFoe, {1: 8, 2: 8}, reason: '8틱 내내');
    expect(dmg.first.amount.toDouble(), closeTo(dmg.last.amount.toDouble(), 1e-6), reason: '감쇠 없음');
  });

  test('laserPierce 0 = 화면 끝까지 전부', () {
    final ev = fire(laser(0));
    expect(ev.whereType<Damage>().map((d) => d.targetId).toSet(), {1, 2, 3, 4});
  });
}

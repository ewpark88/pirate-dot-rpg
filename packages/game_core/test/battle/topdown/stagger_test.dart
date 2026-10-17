import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 계열 행동 v3 5단계 시차 타격: 직사 기관포 연발 · 물수제비 튕김 · 충격 파동 링.
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;

  GameTables withBehavior(String crewId, Map<String, Object?> behavior) {
    final raw = Map<String, String>.of(rawTables);
    final crews = jsonDecode(raw['crews']!) as Map<String, dynamic>;
    for (final c in (crews['crews'] as List).cast<Map<String, dynamic>>()) {
      c.remove('aim');
      if (c['id'] == crewId) c['aim'] = {'intervalSec': 30, 'behavior': behavior};
    }
    raw['crews'] = jsonEncode(crews);
    return GameTables.load(raw);
  }

  List<GameEvent> fire(GameTables t, String crewId, List<(double, double)> at) {
    final g = geometryFor(t, stage) as TopGeometry;
    final f = Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))
      ..geometry = g
      ..guns = [Gun.of(t, crewId, power: 1)];
    var id = 0;
    for (final (dx, dy) in at) {
      f.foes.add(
        Foe(
          id: ++id,
          kind: 'crab',
          layer: 'surface',
          x: g.top.shipX + dx,
          y: g.top.shipY + dy,
          maxHp: BigNum.from(1000000000000),
          speed: 0,
          attack: BigNum.zero,
          gold: BigNum.one,
        ),
      );
    }
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    final s = GameState.newGame(playerId: 'g', seed: 1, now: start);
    for (var i = 0; i < 40; i++) {
      ctx.tick = i;
      Round(f, ctx, CombatStats.of(s, t))
        ..fireGuns()
        ..topdownStep(s);
    }
    return events;
  }

  test('직사 기관포: burst 5 · 0.1초 — 같은 대상에 한 발 ÷ 5를 2틱마다 5번', () {
    final ev = fire(withBehavior('pang', {'burst': 5, 'burstGapSec': 0.1}), 'pang', [(0, -60)]);
    final fired = ev.whereType<AttackFired>().single;
    final dmg = ev.whereType<Damage>().toList();
    expect([for (final d in dmg) d.tick - fired.tick], [0, 2, 4, 6, 8]);
    expect(fired.flightTicks, 8);
    final plain = fire(withBehavior('pang', {}), 'pang', [(0, -60)]).whereType<Damage>().single.amount.toDouble();
    expect(dmg.first.amount.toDouble(), closeTo(plain / 5, plain * 1e-9));
  });

  test('물수제비: hopSec 0.1 — 연쇄 대상을 차례로 2틱씩 늦게', () {
    final ev = fire(withBehavior('otter', {'hopSec': 0.1}), 'otter', [(0, -50), (20, -70), (40, -90)]);
    final fired = ev.whereType<AttackFired>().single;
    final firstHits = <int, int>{};
    for (final d in ev.whereType<Damage>()) {
      firstHits.putIfAbsent(d.targetId, () => d.tick - fired.tick);
    }
    expect(firstHits.values.toList()..sort(), [0, 2, 4]);
  });

  test('충격 파동 링: 가까운 적이 먼저, 먼 적은 거리 ÷ 링 속도만큼 늦게', () {
    final t = withBehavior('turtle', {'ringSpeed': 100});
    final ev = fire(t, 'turtle', [(0, -40), (0, -80)]);
    final fired = ev.whereType<AttackFired>().single;
    final at = {for (final d in ev.whereType<Damage>()) d.targetId: d.tick - fired.tick};
    final near = at[1]!;
    final far = at[2]!;
    expect(near, lessThan(far));
    expect(far - near, closeTo(40 / 100 / (t.waves.tickMs / 1000), 1));
  });
}

import 'dart:convert';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 계열 행동 v3 원형 탄막(사용자 '배를 중심으로 원으로 수많은 폭탄을 사방에, 등급이 오를수록 발 수↑').
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;

  GameTables ring({Map<String, Object?>? projectile}) {
    final raw = Map<String, String>.of(rawTables);
    final crews = jsonDecode(raw['crews']!) as Map<String, dynamic>;
    for (final c in (crews['crews'] as List).cast<Map<String, dynamic>>()) {
      if (c['id'] == 'puffer') {
        c['aim'] = {
          'shape': 'ring',
          'ringCount': 8,
          'topWidth': 4,
          'intervalSec': 30,
          'reach': 200,
          'projectile': ?projectile,
        };
      }
    }
    raw['crews'] = jsonEncode(crews);
    return GameTables.load(raw);
  }

  List<GameEvent> fire(GameTables t, {double seconds = 0.05}) {
    final g = geometryFor(t, stage) as TopGeometry;
    final f = Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))
      ..geometry = g
      ..guns = [Gun.of(t, 'puffer', power: 1)];
    var id = 0;
    for (final deg in [-90.0, 0.0, 90.0, 180.0, -60.0]) {
      final r = deg * math.pi / 180;
      f.foes.add(
        Foe(
          id: ++id,
          kind: 'crab',
          layer: 'surface',
          x: g.top.shipX + math.cos(r) * 60,
          y: g.top.shipY + math.sin(r) * 60,
          maxHp: BigNum.from(1000000000000),
          speed: 0,
          attack: BigNum.zero,
          gold: BigNum.one,
        ),
      );
    }
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    final s = GameState.newGame(playerId: 'r', seed: 1, now: start);
    for (var i = 0; i < (seconds * 1000 / t.waves.tickMs).round(); i++) {
      ctx.tick = i;
      Round(f, ctx, CombatStats.of(s, t), rage: 0)
        ..fireGuns()
        ..topdownStep(s);
    }
    return events;
  }

  test('사방 8발(45°씩, 가까운 적 쪽부터): 광선 위 첫 적만, 한 발 = 한 번 피해 ÷ 8', () {
    final ev = fire(ring());
    final fired = ev.whereType<AttackFired>().toList();
    expect(fired, hasLength(8));
    final dmg = ev.whereType<Damage>().toList();
    expect(dmg.map((d) => d.targetId).toSet(), {1, 2, 3, 4}, reason: '−60°(5번)은 45° 줄 사이라 안 맞음');
    final single = fire(ring()).whereType<Damage>().first.amount.toDouble();
    expect(dmg.every((d) => (d.amount.toDouble() - single).abs() < 1e-6), isTrue);
    expect(fired.where((f) => f.targetIds.isEmpty), hasLength(4), reason: '빈 방향 4발은 연출만');
  });

  test('탄이 날아가면 빈 탄은 MISS 없이, 맞을 탄은 도착 때 피해', () {
    final ev = fire(ring(projectile: {'speed': 200, 'hitRadius': 6}), seconds: 1);
    expect(ev.whereType<AttackMissed>(), isEmpty);
    expect(ev.whereType<Damage>().map((d) => d.targetId).toSet(), {1, 2, 3, 4});
  });
}

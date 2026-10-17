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

/// 계열 행동 v3 집속탄(사용자 '큰 폭탄 하나 → 터진 주변에 작은 폭탄 여러 발이 산개해 연쇄로, 등급별 자탄 수↑').
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;

  GameTables cluster({int bomblets = 4}) {
    final raw = Map<String, String>.of(rawTables);
    final crews = jsonDecode(raw['crews']!) as Map<String, dynamic>;
    for (final c in (crews['crews'] as List).cast<Map<String, dynamic>>()) {
      if (c['id'] == 'volke') {
        c['aim'] = {
          'shape': 'cluster',
          'topRadius': 18,
          'bomblets': bomblets,
          'intervalSec': 30,
          'dotSec': 0,
          'behavior': {
            'kind': 'cluster',
            'bombletRadius': 10,
            'bombletDelaySec': 0.1,
            'scatterRadius': 30,
            'bombletRatio': 1,
          },
        };
      }
    }
    raw['crews'] = jsonEncode(crews);
    return GameTables.load(raw);
  }

  ({List<GameEvent> events, double cx, double cy}) fire(GameTables t) {
    final g = geometryFor(t, stage) as TopGeometry;
    final f = Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))
      ..geometry = g
      ..guns = [Gun.of(t, 'volke', power: 1)];
    final cx = g.top.shipX;
    final cy = g.top.shipY - 70;
    var id = 0;
    for (final (dx, dy) in [(0.0, 0.0), (12.0, 6.0), (-14.0, -8.0), (20.0, -20.0), (-25.0, 15.0)]) {
      f.foes.add(
        Foe(
          id: ++id,
          kind: 'crab',
          layer: 'surface',
          x: cx + dx,
          y: cy + dy,
          maxHp: BigNum.from(1000000000000),
          speed: 0,
          attack: BigNum.zero,
          gold: BigNum.one,
        ),
      );
    }
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    final s = GameState.newGame(playerId: 'c', seed: 1, now: start);
    for (var i = 0; i < 40; i++) {
      ctx.tick = i;
      Round(f, ctx, CombatStats.of(s, t))
        ..fireGuns()
        ..topdownStep(s);
    }
    return (events: events, cx: cx, cy: cy);
  }

  test('본탄이 터진 뒤 자탄 4발이 0.1초(2틱) 간격으로 산개 반경 안에서 차례로 터진다', () {
    final r = fire(cluster());
    final fired = r.events.whereType<AttackFired>().single;
    final bursts = r.events.whereType<BombletBurst>().toList();
    expect(bursts, hasLength(4), reason: '자탄이 또 자탄을 부르지 않는다');
    expect([for (final b in bursts) b.tick - fired.tick], [2, 4, 6, 8]);
    for (final b in bursts) {
      expect(math.sqrt(math.pow(b.x - fired.x, 2) + math.pow(b.y - fired.y, 2)), lessThanOrEqualTo(30 + 1e-9));
      expect(b.radius, 10);
    }
  });

  test('자탄 한 발 피해 = 한 발 피해 × bombletRatio ÷ 자탄 수, 등급별 수, 같은 시드 같은 자리', () {
    final r = fire(cluster());
    final fired = r.events.whereType<AttackFired>().single;
    final main = r.events.whereType<Damage>().where((d) => d.tick == fired.tick).first.amount.toDouble();
    final later = r.events.whereType<Damage>().where((d) => d.tick > fired.tick).map((d) => d.amount.toDouble());
    expect(later, isNotEmpty);
    for (final a in later) {
      expect(a, closeTo(main / 4, main * 1e-9));
    }
    expect(fire(cluster(bomblets: 12)).events.whereType<BombletBurst>(), hasLength(12));
    String spots(GameTables t) => fire(t).events.whereType<BombletBurst>().map((b) => '${b.x},${b.y}').join(';');
    expect(spots(cluster()), spots(cluster()));
  });
}

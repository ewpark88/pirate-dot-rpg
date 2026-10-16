import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 배 위협 (docs/specs/platform-ship-threat.md): (a) 원거리 적, (b) 가까이 등장. 표 값은 기획 초안(S2 표 전 테스트 값).
void main() {
  final raw = Map<String, String>.of(rawTables);
  final waves = jsonDecode(raw['waves']!) as Map<String, dynamic>;
  (waves['top'] as Map<String, dynamic>)['nearSpawn'] = {
    'ratio': 0.15,
    'distanceMin': 40,
    'distanceMax': 80,
    'warnSec': 0.6,
    'midDelayMaxSec': 3,
  };
  raw['waves'] = jsonEncode(waves);
  final t = GameTables.load(raw);
  final start = DateTime.utc(2026, 11);
  const stage = 20;
  final s = GameState.newGame(playerId: 't', seed: 1, now: start).copyWith(
    progress: const Progress(stage: stage, bestStage: stage),
  );
  final geo = geometryFor(t, stage) as TopGeometry;
  final top = geo.top;
  final ranged = EnemyDef.fromJson(
    JsonReader({
      'id': 'spitter',
      'layer': 'surface',
      'hpScale': 1,
      'speed': 0,
      'role': 'basic',
      'ranged': {'range': 90, 'intervalSec': 2.5, 'damageRatio': 0.35, 'projectileSpeed': 120, 'kind': 'spit'},
    }, 'test'),
  );

  Foe spitter(double gapFromHull, {int id = 1}) => Foe(
    id: id,
    kind: 'spitter',
    layer: 'surface',
    x: top.shipX + top.hullHalfWidth + top.mobRadius + gapFromHull,
    y: top.shipY + top.hullOffset,
    maxHp: BigNum.from(1000),
    speed: 0,
    attack: BigNum.from(100),
    gold: BigNum.one,
    def: ranged,
  );

  List<GameEvent> run(Field f, double seconds, {int seed = 1}) {
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(seed), onEvent: events.add);
    final r = Round(f, ctx, CombatStats.of(s, t), rage: 0);
    for (var i = 0; i < (seconds / r.dt).round(); i++) {
      ctx.tick = i;
      for (final e in f.foes) {
        geo.advance(e, e.speed, r.dt);
      }
      r.topdownStep(s);
    }
    return events;
  }

  Field field() => Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))..geometry = geo;

  test('(a) 원거리 적: 사거리(90) 안이면 바로 쏘고 2.5초마다, 탄이 날아가 닿으면 공격력 × 0.35 배 피해', () {
    final f = field()..foes.addAll([spitter(60), spitter(120, id: 2)]);
    final events = run(f, 3);
    final fired = events.whereType<EnemyFired>().toList();
    expect(fired.map((e) => e.enemyId), [1, 1], reason: '0초·2.5초, 사거리 밖(120)은 안 쏨');
    expect(fired.first.kind, 'spit');
    expect(fired.first.flightTicks, (60 / 120 / (1 / 20)).round());
    final hits = events.whereType<ShipDamaged>().toList();
    expect(hits, hasLength(2));
    expect(hits.first.amount.toDouble(), closeTo(35, 1e-6));
    expect(hits.first.tick - fired.first.tick, fired.first.flightTicks - 1);
    expect(f.shipHp.toDouble(), closeTo(930, 1e-6));
  });

  test('(b) 가까이 등장: 파의 15%가 배 몸통 40~80 자리에서 0.6초 예고 뒤 솟아오름, 예고 중엔 조준 안 됨', () {
    final f = field();
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(3), onEvent: (_) {});
    geo.spawnWave(f, stage, ctx, count: 20);
    final near = f.foes.where((e) => e.nearX != null).toList();
    expect(near, hasLength(3));
    final events = run(f, 4);
    final emerging = events.whereType<EnemyEmerging>().toList();
    expect(emerging.map((e) => e.enemyId).toSet(), near.map((e) => e.id).toSet());
    for (final e in emerging) {
      expect(e.warnTicks, closeTo(12, 1));
      final gap = geo.hullGap(e.x, e.y) - top.mobRadius;
      expect(gap, inInclusiveRange(40 - 1, 80 + 1));
    }
    // 예고 중 한 마리: 화면에는 emerging, 조준·오라 대상 아님
    final f2 = field();
    geo.spawnWave(
      f2,
      stage,
      SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(3), onEvent: (_) {}),
      count: 20,
    );
    final first = f2.foes.firstWhere((e) => e.nearX != null && e.holdSec <= 0.6 + 1e-9);
    run(f2, 0.1);
    expect(first.emerging, isTrue);
    expect(first.view().emerging, isTrue);
    expect(geo.onScreen(first), isFalse);
  });

  test('표에 없으면 꺼짐, 이벤트·EnemyView.emerging JSON 왕복', () {
    final plain = geometryFor(GameTables.load(rawTables), stage) as TopGeometry;
    final f = field()..geometry = plain;
    plain.spawnWave(
      f,
      stage,
      SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(3), onEvent: (_) {}),
      count: 20,
    );
    expect(f.foes.where((e) => e.nearX != null), isEmpty);
    for (final e in <GameEvent>[
      const EnemyFired(3, enemyId: 1, fromX: 1, fromY: 2, flightTicks: 10, kind: 'spit'),
      const EnemyEmerging(3, enemyId: 2, x: 1, y: 2, warnTicks: 12),
    ]) {
      expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson());
    }
    final v = spitter(0).view();
    expect(v.toJson().containsKey('emerging'), isFalse, reason: '평소엔 키 없음(옛 골든·세이브 그대로)');
  });
}

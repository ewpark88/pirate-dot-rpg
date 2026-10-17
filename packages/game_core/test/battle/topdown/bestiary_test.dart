import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show spawnWaveFoes, startBoss;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

typedef Arena = ({Field f, List<GameEvent> events, SystemContext ctx, Foe boss, TopGeometry g});

/// 도감 v2 엔진 (docs/specs/platform-bestiary-v2.md, 사용자 승인): 보스 순환·대보스, 먹물·삼키기·분열, 자폭·떼.
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;

  GameTables patch(void Function(Map<String, dynamic> regions) f) {
    final raw = Map<String, String>.of(rawTables);
    final regions = jsonDecode(raw['regions']!) as Map<String, dynamic>;
    f(regions);
    raw['regions'] = jsonEncode(regions);
    return GameTables.load(raw);
  }

  List<Map<String, dynamic>> bosses(Map<String, dynamic> r) => (r['bosses'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> enemies(Map<String, dynamic> r) => (r['enemies'] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic> coral(Map<String, dynamic> r) => (r['regions'] as List).cast<Map<String, dynamic>>().first;

  test('보스 순환(같은 스테이지 = 같은 보스) · 10단위 대보스 · 25 중간 · 50 해역 그대로, 키 없으면 지금', () {
    final t = patch((r) {
      coral(r)
        ..['bossRotation'] = ['enemy_ship', 'raider_ship', 'storm_pirate', 'icebreaker']
        ..['wallBoss'] = 'giant_hermit';
      r['wallEvery'] = 10;
    });
    expect({for (var s = 1; s <= 9; s++) t.regions.bossAt(s).id}, hasLength(4));
    expect(t.regions.bossAt(7).id, t.regions.bossAt(7).id);
    expect(t.regions.bossAt(10).id, 'giant_hermit');
    expect(t.regions.bossAt(20).id, 'giant_hermit');
    expect(t.regions.bossAt(25).id, t.regions.regions.first.midBoss);
    expect(t.regions.bossAt(50).id, t.regions.regions.first.regionBoss);
    final plain = GameTables.load(rawTables);
    expect({for (var s = 1; s <= 9; s++) plain.regions.bossAt(s).id}, {plain.regions.regions.first.boss});
  });

  Arena arena(GameTables t) {
    final g = geometryFor(t, stage) as TopGeometry;
    final f = Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))..geometry = g;
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    startBoss(f, stage, ctx, emit: false, x: g.top.shipX, y: g.top.shipY - g.top.bossStandoff);
    return (f: f, events: events, ctx: ctx, boss: f.foes.firstWhere((e) => e.boss), g: g);
  }

  void run(Arena a, int ticks) {
    final s = GameState.newGame(playerId: 'b', seed: 1, now: start);
    for (var i = 0; i < ticks; i++) {
      a.ctx.tick += 1;
      Round(a.f, a.ctx, CombatStats.of(s, a.ctx.tables)).topdownStep(s);
    }
  }

  Foe mob(TopGeometry g, int id, double dx, double dy, {EnemyDef? def}) => Foe(
    id: id,
    kind: 'crab',
    layer: 'surface',
    x: g.top.shipX + dx,
    y: g.top.shipY + dy,
    maxHp: BigNum.from(100),
    speed: 0,
    attack: BigNum.from(500),
    gold: BigNum.one,
    def: def,
  );

  GameTables withPattern(Map<String, Object?> p, {List<double>? splitAt, double rest = 0.1}) => patch((r) {
    for (final b in bosses(r)) {
      b
        ..['patterns'] = [p]
        ..['restSec'] = rest
        ..['firstRestSec'] = 0.05;
      if (splitAt != null) b['splitAt'] = splitAt;
    }
  });

  test('먹물: 보스와 배 사이 원 — 그 안 적은 durationSec 동안 조준되지 않고, 지나면 다시', () {
    final a = arena(withPattern({'type': 'ink', 'warnSec': 0.1, 'radiusShipMul': 2, 'durationSec': 1}, rest: 30));
    final inside = mob(a.g, 900, 0, -a.g.top.bossStandoff / 2);
    a.f.foes.add(inside);
    final probe = AttackDef.fromJson(JsonReader({'shape': 'single'}, 't'));
    expect(a.g.eligible(probe, [inside]), [inside]);
    run(a, 4);
    final ink = a.events.whereType<InkCloud>().single;
    expect(a.g.eligible(probe, [inside]), isEmpty, reason: '먹물 속');
    run(a, ink.ticks);
    expect(a.g.eligible(probe, [inside]), [inside], reason: '먹물이 걷힘');
  });

  test('삼키기: 보스 둘레 잡몹을 삼켜(보상 없음) 마리당 최대 HP × healRatio 회복, 먼 잡몹은 그대로', () {
    final a = arena(withPattern({'type': 'swallow', 'warnSec': 0.1, 'radiusShipMul': 1, 'healRatio': 0.1}));
    a.boss.hp = a.boss.maxHp.times(0.5);
    final near = mob(a.g, 901, 0, -a.g.top.bossStandoff + 10);
    final far = mob(a.g, 902, 0, 40);
    a.f.foes.addAll([near, far]);
    run(a, 4);
    final ev = a.events.whereType<BossSwallowed>().single;
    expect(ev.eaten, [901]);
    expect(a.f.foes, isNot(contains(near)));
    expect(a.f.foes, contains(far));
    expect((a.boss.hp / a.boss.maxHp).toDouble(), closeTo(0.6, 1e-9));
    expect(a.events.whereType<Kill>(), isEmpty);
  });

  test('분열: HP 50% 아래로 내려가면 둘로(각 절반), 문턱은 한 번', () {
    final a = arena(withPattern({'type': 'volley', 'warnSec': 9, 'count': 1, 'speed': 100}, splitAt: [0.5]));
    a.boss.hp = a.boss.maxHp.times(0.4);
    run(a, 1);
    final split = a.events.whereType<BossSplit>().single;
    final both = a.f.foes.where((e) => e.boss && e.alive).toList();
    expect(both, hasLength(2));
    expect(split.childId, both.last.id);
    for (final b in both) {
      expect((b.hp / b.maxHp).toDouble(), closeTo(0.2, 1e-9));
    }
    run(a, 3);
    expect(a.events.whereType<BossSplit>(), hasLength(1));
  });

  test('분열한 보스는 둘 다 쓰러져야 격파(엔진): 두 몸의 Kill이 모두 BossCleared 앞에', () {
    final t = withPattern({'type': 'volley', 'warnSec': 9, 'count': 1, 'speed': 100}, splitAt: [0.5], rest: 30);
    final e = CoreEngine(
      tables: t,
      clock: ManualClock(start),
      initial: GameState.newGame(playerId: 'x', seed: 1, now: start).copyWith(
        progress: const Progress(stage: 5, bestStage: 5),
        crews: const {'octo': CrewState(level: 60), 'pang': CrewState(level: 60), 'sword': CrewState(level: 60)},
      ),
    )..enqueue(const OpSpawnBoss());
    final events = <GameEvent>[];
    for (var i = 0; i < 1200 && events.whereType<BossCleared>().isEmpty; i++) {
      e.tick();
      events.addAll(e.drainEvents());
    }
    final split = events.whereType<BossSplit>().single;
    final cleared = events.whereType<BossCleared>().single;
    final kills = {for (final k in events.whereType<Kill>()) k.targetId: k.tick};
    expect(kills[split.parentId], isNotNull);
    expect(kills[split.childId], isNotNull);
    expect(cleared.tick, greaterThanOrEqualTo(kills.values.reduce((a, b) => a > b ? a : b)));
    final firstBody = [kills[split.parentId]!, kills[split.childId]!].reduce((a, b) => a < b ? a : b);
    expect(events.whereType<BossCleared>().where((c) => c.tick < firstBody), isEmpty);
  });

  test('자폭: 배에 닿으면 터져 상한 × capMul 피해·사라짐(보상 없음), 먼저 잡히면 주변 적에게 폭발', () {
    final t = patch((r) {
      enemies(r).firstWhere((e) => e['id'] == 'crab')['bomber'] = {'capMul': 2, 'blastRadius': 30, 'blastRatio': 0.5};
    });
    final a = arena(t);
    a.f.foes.remove(a.boss);
    final def = t.regions.enemies['crab'];
    final bow = a.g.top.hullOffset - a.g.top.hullHalfLength; // 뱃머리 끝(캡슐 중심은 고물 쪽으로 hullOffset)
    final touching = mob(a.g, 910, 0, bow - a.g.top.mobRadius / 2, def: def);
    a.f.foes.add(touching);
    run(a, 1);
    final blast = a.events.whereType<BomberBlast>().single;
    expect(blast.onShip, isTrue);
    expect(a.f.foes, isNot(contains(touching)));
    final cap = 1000 * t.waves.raw.number('shipHitCap') * 2;
    expect(a.events.whereType<ShipDamaged>().single.amount.toDouble(), closeTo(cap, 1e-6));
    final dead = mob(a.g, 911, 0, -120, def: def)..hp = BigNum.zero;
    final neighbor = mob(a.g, 912, 10, -120);
    a.f.foes.addAll([dead, neighbor]);
    run(a, 1);
    expect(a.events.whereType<BomberBlast>().last.onShip, isFalse);
    expect(neighbor.hp.toDouble(), closeTo(50, 1e-6), reason: '최대 HP 100 × 0.5');
  });

  test('떼: 한 자리에 swarmCount마리, HP는 ÷ 수(파 총량 그대로)', () {
    GameTables only(int swarm) => patch((r) {
      coral(r)['enemies'] = ['crab'];
      if (swarm > 0) enemies(r).firstWhere((e) => e['id'] == 'crab')['swarmCount'] = swarm;
    });
    Field wave(GameTables tables) {
      final f = Field(stage: 5, shipHpMax: BigNum.one, shipHp: BigNum.one);
      spawnWaveFoes(
        f,
        5,
        SystemContext(tables: tables, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: (_) {}),
      );
      return f;
    }

    final swarm = wave(only(5));
    final normal = wave(only(0));
    expect(swarm.foes.length, normal.foes.length * 5);
    double total(Field f) => f.foes.fold(0, (s, e) => s + e.maxHp.toDouble());
    expect(total(swarm), closeTo(total(normal), total(normal) * 1e-9));
  });
}

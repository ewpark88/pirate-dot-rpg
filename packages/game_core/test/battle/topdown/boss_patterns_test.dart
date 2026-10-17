import 'dart:convert';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show startBoss;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 보스 행동 v2 (docs/specs/platform-boss-patterns.md, 사용자 결정 예고 0.6초): 쉼 → 예고 → 동작, 순서대로.
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;

  GameTables withPatterns(List<Map<String, Object?>> patterns, {double rest = 2, double? first}) {
    final raw = Map<String, String>.of(rawTables);
    final regions = jsonDecode(raw['regions']!) as Map<String, dynamic>;
    for (final b in (regions['bosses'] as List).cast<Map<String, dynamic>>()) {
      b['patterns'] = patterns;
      b['restSec'] = rest;
      if (first == null) {
        b.remove('firstRestSec');
      } else {
        b['firstRestSec'] = first;
      }
    }
    raw['regions'] = jsonEncode(regions);
    return GameTables.load(raw);
  }

  const volley = {'type': 'volley', 'warnSec': 0.6, 'count': 3, 'speed': 200, 'damageRatio': 0.3, 'spreadDeg': 40};
  const charge = {'type': 'charge', 'warnSec': 0.6, 'speedMul': 4, 'damageRatio': 1.5, 'capMul': 2};
  const blast = {'type': 'blast', 'warnSec': 0.6, 'damageRatio': 1.0, 'radiusShipMul': 2};
  const summon = {'type': 'summon', 'warnSec': 0.6, 'count': 4};

  ({Field f, List<GameEvent> events, Foe boss}) fight(GameTables t, double seconds, {void Function(Foe)? onBoss}) {
    final s = GameState.newGame(playerId: 'b', seed: 1, now: start).copyWith(
      progress: const Progress(stage: stage, bestStage: stage),
    );
    final g = geometryFor(t, stage) as TopGeometry;
    final f = Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))..geometry = g;
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    startBoss(f, stage, ctx, emit: false, x: g.top.shipX, y: g.top.shipY - g.top.bossStandoff);
    final boss = f.foes.firstWhere((e) => e.boss);
    boss.y = g.top.shipY - g.top.standoffOf(boss); // 큰 보스(bossScale)는 standoff가 더 멀다
    onBoss?.call(boss);
    final stats = CombatStats.of(s, t);
    for (var i = 0; i < (seconds * 1000 / t.waves.tickMs).round(); i++) {
      ctx.tick = i;
      Round(f, ctx, stats)
        ..moveFoes()
        ..topdownStep(s);
    }
    return (f: f, events: events, boss: boss);
  }

  final tick = rawTables.isEmpty ? 0 : GameTables.load(rawTables).waves.tickMs / 1000;
  int ticks(double sec) => (sec / tick).round();

  test('패턴 없으면 지금처럼(BossPatternShown 없음, 기본 원거리 공격)', () {
    final r = fight(withPatterns([]), 5);
    expect(r.events.whereType<BossPatternShown>(), isEmpty);
    expect(r.events.whereType<BossFired>(), isNotEmpty);
  });

  test('탄막: 쉼 2초 → 예고 0.6초(부채꼴) → 3발 EnemyFired(boss_shell) → 배 피해 3번, 예고·동작 중엔 기본 공격 쉼', () {
    final r = fight(withPatterns([volley]), 4);
    final shown = r.events.whereType<BossPatternShown>().toList();
    expect(shown.map((e) => '${e.kind}:${e.phase}').take(2), ['volley:warn', 'volley:act']);
    expect(shown[0].tick, ticks(2) - 1);
    expect(shown[0].warnTicks, ticks(0.6));
    expect(shown[1].tick - shown[0].tick, ticks(0.6));
    expect(shown[0].count, 3);
    final fired = r.events.whereType<EnemyFired>().where((e) => e.kind == 'boss_shell').toList();
    expect(fired, hasLength(3));
    final hits = r.events.whereType<ShipDamaged>().where((e) => e.tick > shown[1].tick && e.fromY == fired.first.fromY);
    expect(hits.length, greaterThanOrEqualTo(3));
    final during = r.events.whereType<BossFired>().where((e) => e.tick > shown[0].tick && e.tick <= shown[1].tick);
    expect(during, isEmpty);
  });

  test('firstRestSec: 등장 뒤 첫 패턴은 그만큼 빨리, 그다음부터는 restSec', () {
    final r = fight(withPatterns([volley], first: 0.6), 6);
    final warns = r.events.whereType<BossPatternShown>().where((e) => e.phase == 'warn').toList();
    expect(warns.first.tick, ticks(0.6) - 1);
    expect(warns[1].tick - warns[0].tick, ticks(0.6) + ticks(2), reason: '예고 0.6 + 쉼 2');
  });

  test('돌진: 예고 뒤 배로 달려와 한 번 큰 피해(상한 × capMul), 다시 standoff로 돌아가 다음 패턴', () {
    final t = withPatterns([charge, blast], rest: 1);
    final r = fight(t, 6);
    final act = r.events.whereType<BossPatternShown>().firstWhere((e) => e.kind == 'charge' && e.phase == 'act');
    final hit = r.events.whereType<ShipDamaged>().firstWhere((e) => e.tick > act.tick);
    expect(hit.amount.toDouble(), closeTo(1000 * t.waves.raw.number('shipHitCap') * 2, 1e-6));
    final g = geometryFor(t, stage) as TopGeometry;
    final after = r.events.whereType<BossPatternShown>().firstWhere((e) => e.kind == 'blast' && e.phase == 'warn');
    expect(after.tick, greaterThan(hit.tick));
    final d = math.sqrt(math.pow(after.x - g.top.shipX, 2) + math.pow(after.y - g.top.shipY, 2));
    expect(d, closeTo(g.top.standoffOf(r.boss), 2), reason: '돌진 뒤 standoff로 돌아왔다');
    expect(after.radius, closeTo(g.top.shipRadius * 2, 1e-9));
  });

  test('장판·소환: 예고 원이 터지면 배 피해, 소환은 잡몹 count마리', () {
    final r = fight(withPatterns([summon, blast], rest: 1), 4);
    final summoned = r.f.foes.where((e) => !e.boss).length;
    expect(summoned, 4);
    final blastAct = r.events.whereType<BossPatternShown>().firstWhere((e) => e.kind == 'blast' && e.phase == 'act');
    expect(r.events.whereType<ShipDamaged>().where((e) => e.tick == blastAct.tick), hasLength(1));
  });

  test('예고 중 기절되면 그 패턴은 취소(cancel), 다음 패턴으로', () {
    final warn = fight(withPatterns([blast, volley]), 3.5).events.whereType<BossPatternShown>().first;
    final t = withPatterns([blast, volley]);
    final s = GameState.newGame(playerId: 'b', seed: 1, now: start).copyWith(
      progress: const Progress(stage: stage, bestStage: stage),
    );
    final g = geometryFor(t, stage) as TopGeometry;
    final f = Field(stage: stage, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))..geometry = g;
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    startBoss(f, stage, ctx, emit: false, x: g.top.shipX, y: g.top.shipY - g.top.bossStandoff);
    final boss = f.foes.firstWhere((e) => e.boss);
    boss.y = g.top.shipY - g.top.standoffOf(boss); // 큰 보스(bossScale)는 standoff가 더 멀다
    for (var i = 0; i < ticks(3.5); i++) {
      ctx.tick = i;
      if (i == warn.tick + 1) boss.stunTimer = 1;
      Round(f, ctx, CombatStats.of(s, t))
        ..moveFoes()
        ..topdownStep(s);
    }
    final shown = events.whereType<BossPatternShown>().map((e) => '${e.kind}:${e.phase}').toList();
    expect(shown.take(2), ['blast:warn', 'blast:cancel']);
    // 취소된 장판은 터지지 않는다 — 예고가 끝났을 틱(장판이 터졌을 때)에 배 피해 없음. 기본 포탄 피해는 따로 온다(보스 x가 같아
    // 예전 걸러내기 fromX == boss.x는 보스가 원을 돌아 x가 바뀔 때만 비어 있었다 — 큰 보스는 돌지 않는다, bossScale).
    expect(events.whereType<ShipDamaged>().where((e) => e.tick == warn.tick + ticks(0.6)), isEmpty);
  });

  test('바다 괴물(ambush): meta.seaEvents 패턴이 있으면 몸통에 붙지 않고 standoff에서 돌진·복귀(사용자 결정)', () {
    GameTables serpentWith(Map<String, Object?>? pattern) {
      final raw = Map<String, String>.of(rawTables);
      final meta = jsonDecode(raw['meta']!) as Map<String, dynamic>;
      for (final e in ((meta['seaEvents'] as Map<String, dynamic>)['events'] as List).cast<Map<String, dynamic>>()) {
        if (e['id'] != 'ambush') continue;
        if (pattern == null) {
          e.remove('patterns');
        } else {
          e
            ..['patterns'] = [pattern]
            ..['restSec'] = 1.5;
        }
      }
      raw['meta'] = jsonEncode(meta);
      return GameTables.load(raw);
    }

    final t = serpentWith(charge);
    final g = geometryFor(t, stage) as TopGeometry;
    ({int alive, int glued, List<GameEvent> events}) run(GameTables tables) {
      final engine =
          CoreEngine(
              tables: tables,
              clock: ManualClock(start),
              initial: GameState.newGame(playerId: 's', seed: 3, now: start).copyWith(
                progress: const Progress(stage: stage, bestStage: stage),
                crews: const {},
              ),
            ) // 선원 없음·무적: 움직임만 본다
            ..enqueue(const OpSetInvincible(on: true))
            ..enqueue(const OpSeaEvent('ambush'));
      var alive = 0;
      var glued = 0;
      final events = <GameEvent>[];
      for (var i = 0; i < ticks(20); i++) {
        engine.tick();
        events.addAll(engine.drainEvents());
        final serpent = engine.state.battle!.enemies.where((e) => e.eventKind == 'ambush').firstOrNull;
        if (serpent == null) continue;
        alive += 1;
        if (g.hullGap(serpent.x, serpent.y) <= g.top.mobRadius * 2) glued += 1;
      }
      return (alive: alive, glued: glued, events: events);
    }

    final now = run(t);
    final before = run(serpentWith(null));
    expect(now.events.whereType<BossPatternShown>().where((e) => e.kind == 'charge' && e.phase == 'act'), isNotEmpty);
    expect(before.glued / before.alive, greaterThan(0.5), reason: '옛: 몸통에 붙어 박치기');
    expect(now.glued / now.alive, lessThan(0.2), reason: '새: 대부분 standoff에서 돌다가 돌진');
  });
}

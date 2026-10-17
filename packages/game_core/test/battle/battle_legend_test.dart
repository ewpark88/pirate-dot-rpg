import 'dart:math' as math;

// 전설 고유 능력 수용 기준 (docs/specs/battle-m3-legend.md).
import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/legend.dart';
import 'package:game_core/src/battle/skills.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/battle/topdown/top_field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:test/test.dart';

import 'family_tables.dart';

void main() {
  final tables = familyTables(); // 계열 기본 규칙(선원 aim·traitScale 없음)
  final w = tables.waves;
  final start = DateTime.utc(2026, 11);
  final legend = tables.rarities.rarities.indexWhere((r) => r.id == 'legend');
  late List<GameEvent> events;
  setUp(() => events = []);

  SystemContext ctx() =>
      SystemContext(tables: tables, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
  GameState game() => GameState.newGame(playerId: 't', seed: 7, now: start);
  var nextId = 1;
  Foe foe(double x, double y, {double speed = 0, bool boss = false, String layer = 'surface'}) => Foe(
    id: nextId++,
    kind: 'crab',
    layer: layer,
    x: x,
    y: y,
    maxHp: BigNum.from(1e12),
    speed: speed,
    attack: BigNum.one,
    gold: BigNum.one,
    boss: boss,
  );
  Field field(List<Foe> foes) =>
      Field(stage: 1, shipHpMax: BigNum.from(100), shipHp: BigNum.from(100))..foes.addAll(foes);
  Gun gun(String crewId, int rarity) => Gun.of(tables, crewId, power: 1, rarity: rarity);
  Round round(Field f) => Round(f, ctx(), CombatStats.of(game(), tables));
  double dealt(int id) =>
      events.whereType<Damage>().where((d) => d.targetId == id).fold(0, (s, d) => s + d.amount.toDouble());

  test('1. 전설 미만엔 없음, 전설은 기본 값, 신화는 mythic 값', () {
    expect(gun('octo', legend - 1).legend, isNull);
    expect(gun('octo', legend).legend!.zone!.radius, 20);
    expect(gun('octo', legend + 1).legend!.zone!.radius, 40);
  });

  test('2. extraProjectiles: 서로 다른 대상에 더 쏘고, 한 발 피해는 전체 발수로 나눈다', () {
    // 투척 사거리(skills reach + crabs 보정) 안쪽에 셋.
    final foes = [foe(100, 100), foe(140, 100), foe(180, 100)];
    final g = gun('crabs', legend)..cooldown = 0; // 사다리 전설 2발 + 전설 1발 = 3발
    final r = round(field(foes)..guns = [g])..fireGuns();
    expect(events.whereType<AttackFired>(), hasLength(3));
    final crit = events.whereType<Damage>().first.crit;
    final perShot = r.damageOf(g, g.attack.power * (crit ? r.stats.critMultiplier : 1) / 3).toDouble();
    for (final f in foes) {
      expect(dealt(f.id), closeTo(perShot, perShot * 1e-9));
    }
  });

  test('3. extraChains는 연쇄 대상을 늘리고, noFalloff면 감쇠가 없다', () {
    final foes = [for (var i = 0; i < 6; i++) foe(100.0 + i * 15, 100)];
    final volt = gun('volt', legend);
    final v = extendVolley(
      volt,
      (x: 100, y: 100, hits: spread([foes.first], w)),
      foes,
      w,
      geometry: TopGeometry.of(w),
      rng: XorShiftRng(1),
    );
    expect(v.hits, hasLength(1 + volt.legend!.extraChains));
    expect(v.hits[1].factor, lessThan(1));
    final nar = gun('nar', legend);
    final pierced = (x: 100.0, y: 100.0, hits: spread(foes.take(4).toList(), w, falloff: true));
    expect(
      extendVolley(
        nar,
        pierced,
        foes,
        w,
        geometry: TopGeometry.of(w),
        rng: XorShiftRng(1),
      ).hits.every((h) => h.factor == 1),
      isTrue,
    );
  });

  test('4. 장판 감속: 안의 적은 (1 − slow)배로 움직이고, 보스는 절반만', () {
    // 보스 정지·감속 구간(뱃머리 + standoff + slowZone) 밖에서 잰다.
    final mob = foe(240, 100, speed: 20);
    final boss = foe(240, 100, speed: 20, boss: true);
    final f = field([mob, boss]);
    final r = round(f);
    final octo = gun('octo', legend);
    spawnLegendZone(r, octo, 240, 100);
    r
      ..tickZones()
      ..moveFoes();
    final slow = octo.legend!.zone!.slow;
    // 탑다운: 배 중심 쪽으로 다가간 거리. 잡몹은 mobSpeedScale배(보스 제외), 접근 원 안이라 해류 없음.
    final top = TopField.of(w);
    double dist(Foe e) => math.sqrt(math.pow(e.x - top.shipX, 2) + math.pow(e.y - top.shipY, 2));
    final d0 = math.sqrt(math.pow(240 - top.shipX, 2) + math.pow(100 - top.shipY, 2));
    expect(d0, lessThan(top.approachRadius));
    expect(d0 - dist(mob), closeTo(20 * r.dt * (1 - slow) * top.mobSpeedScale, 1e-9));
    expect(d0 - dist(boss), closeTo(20 * r.dt * (1 - slow * tables.skills.bossControlFactor), 1e-9));
  });

  test('5. 화상: burnSec 동안 Damage, 합 = 맞힌 피해 × burnRatio', () {
    final target = foe(200, 100);
    final f = field([target]);
    final r = round(f);
    final starry = gun('starry', legend);
    applyOnHit(r, starry, [target], BigNum.from(1000), x: 200, y: 100);
    final hit = starry.legend!.onHit;
    for (var i = 0; i < (hit.burnSec / r.dt).round() + 2; i++) {
      r.tickStatus();
    }
    expect(dealt(target.id), closeTo(1000 * hit.burnRatio, 1000 * hit.burnRatio * 0.01));
  });

  test('6. 취약: 다른 선원 피해가 (1 + vulnerable)배, 겹치지 않는다', () {
    final target = foe(200, 100);
    final r = round(field([target]));
    final lamp = gun('lamp', legend);
    applyOnHit(r, lamp, [target], BigNum.one, x: 200, y: 100);
    applyOnHit(r, lamp, [target], BigNum.one, x: 200, y: 100);
    events.clear();
    r.strike((x: 200, y: 100, hits: [(foe: target, factor: 1.0)]), BigNum.from(100), crewId: 'octo');
    expect(dealt(target.id), closeTo(100 * (1 + lamp.legend!.onHit.vulnerable), 1e-6));
  });

  test('7. 전설 장판: ZoneSpawned, 주기 기절, sec 뒤 사라짐', () {
    final target = foe(200, 124, layer: 'underwater');
    final f = field([target]);
    final r = round(f);
    final jelly = gun('jelly', legend);
    spawnLegendZone(r, jelly, 200, 124);
    expect(events.whereType<ZoneSpawned>(), hasLength(1));
    final z = jelly.legend!.zone!;
    var stunned = false;
    for (var i = 0; i < (z.sec / r.dt).round(); i++) {
      r
        ..tickZones()
        ..moveFoes();
      stunned |= target.stunned;
    }
    expect(stunned, isTrue);
    expect(f.zones, isEmpty);
  });

  test('8. critBurst: 치명타일 때만 주변 적이 맞는다', () {
    final center = foe(200, 100);
    final near = foe(205, 100);
    final far = foe(260, 100);
    final r = round(field([center, near, far]));
    final pang = gun('pang', legend);
    final v = (x: 200.0, y: 100.0, hits: [(foe: center, factor: 1.0)]);
    critBurst(r, pang, v, BigNum.from(100), crit: false);
    expect(dealt(near.id), 0);
    critBurst(r, pang, v, BigNum.from(100), crit: true);
    expect(dealt(near.id), closeTo(100 * tables.skills.critBurstDamage, 1e-6));
    expect(dealt(far.id), 0);
  });

  test('9. 선원 40명 모두 전설 능력이 있다', () {
    for (final c in tables.crews.crews) {
      expect(tables.skills.legendFor(c.id, legend + 1, legend), isNotNull, reason: c.id);
    }
  });

  test('10. 같은 시드 → 같은 결과 (전설 편성)', () {
    String run() {
      final e = CoreEngine(
        tables: tables,
        clock: ManualClock(start),
        initial: game().copyWith(
          progress: const Progress(stage: 60, bestStage: 60),
          crews: {
            for (final id in ['octo', 'volt', 'jelly', 'lamp']) id: const CrewState(level: 50),
          },
        ),
      )..advance(400);
      return e.drainEvents().map((x) => x.toJson()).join();
    }

    expect(run(), run());
  });
}

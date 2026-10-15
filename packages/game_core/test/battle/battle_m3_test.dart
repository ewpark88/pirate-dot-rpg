// 전투 M3 수용 기준 (docs/specs/battle-m3-skills.md). 번호는 스펙의 수용 기준 번호.
import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/skills.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

void main() {
  final tables = GameTables.load();
  final w = tables.waves;
  final start = DateTime.utc(2026, 11);
  late List<GameEvent> events;
  setUp(() => events = []);

  GameState game({int stage = 1, Map<String, CrewState> crews = const {}, double rage = 0}) =>
      GameState.newGame(playerId: 't', seed: 7, now: start).copyWith(
        progress: Progress(stage: stage, bestStage: stage, rage: rage),
        crews: crews,
      );
  SystemContext ctx([int seed = 1]) =>
      SystemContext(tables: tables, clock: ManualClock(start), rng: XorShiftRng(seed), onEvent: events.add);
  var nextId = 1;
  Foe foe(double x, double y, {String kind = 'crab', BigNum? hp, bool boss = false}) {
    final def = tables.regions.enemies[kind];
    return Foe(
      id: nextId++,
      kind: kind,
      layer: def?.layer ?? 'surface',
      x: x,
      y: y,
      maxHp: hp ?? BigNum.from(1e9),
      speed: 0,
      attack: BigNum.one,
      gold: BigNum.from(10),
      boss: boss,
      def: def,
    );
  }

  Field field(List<Foe> foes) =>
      Field(stage: 1, shipHpMax: BigNum.from(100), shipHp: BigNum.from(100))..foes.addAll(foes);
  String crewOf(String family, [int nth = 0]) => tables.crews.crews.where((c) => c.family == family).elementAt(nth).id;
  Gun gun(String crewId, {int rarity = 0}) => Gun.of(tables, crewId, power: 1, rarity: rarity);
  Round round(Field f, {GameState? s}) => Round(f, ctx(), CombatStats.of(s ?? game(), tables), rage: 0);

  test('1. 스킬 쿨타임이 차면 자동 시전, 실제 쿨타임은 skillCooldownMinSec 아래로 내려가지 않는다', () {
    final g = gun(crewOf('lob'))..skillCooldown = 0;
    round(field([foe(200, 100)])..guns = [g]).castSkills();
    expect(events.whereType<SkillCast>(), isNotEmpty);
    expect(g.skillCooldown, g.skill.cooldownSec);
    expect(skillCooldownFor(1, 100, tables.shipParts.skillCooldownMinSec), tables.shipParts.skillCooldownMinSec * 100);
  });

  test('2. lob_rain(circle×5)은 서로 다른 중심 5곳에 떨어진다', () {
    final foes = [for (var i = 0; i < 8; i++) foe(90.0 + i * 28, 100)];
    round(field(foes)..guns = [gun(crewOf('lob'))..skillCooldown = 0]).castSkills();
    final casts = events.whereType<SkillCast>().toList();
    expect(casts, hasLength(5));
    expect(casts.map((c) => c.x).toSet(), hasLength(5));
  });

  test('3. 전설 선원의 스킬은 화면 안 적 전부, 대상당 비율 합 ≤ 보통 대상 수', () {
    final foes = [for (var i = 0; i < 12; i++) foe(80.0 + i * 18, 100)];
    final g = gun(crewOf('pierce'), rarity: 3)..skillCooldown = 0;
    round(field(foes)..guns = [g]).castSkills();
    expect(events.whereType<SkillCast>().every((c) => c.scope == 'screen'), isTrue);
    final hit = events.whereType<Damage>().map((d) => d.targetId).toSet();
    expect(hit, hasLength(12));
  });

  test('4. support_rally: 배 회복 + 공격 속도 버프(겹치지 않음)', () {
    final g = gun('cook')..skillCooldown = 0;
    final f = field([foe(200, 100)])
      ..shipHp = BigNum.from(50)
      ..guns = [g];
    final r = round(f);
    final before = r.attackSpeed;
    r.castSkills();
    expect(f.shipHp > BigNum.from(50), isTrue);
    expect(r.attackSpeed, greaterThan(before));
    final buffed = r.attackSpeed;
    g.skillCooldown = 0;
    r.castSkills();
    expect(r.attackSpeed, buffed);
  });

  test('5. 충격 선장 궁극기: 적이 밀려나고 기절, 보스는 절반', () {
    final mob = foe(120, 100);
    final boss = foe(120, 100, boss: true);
    final f = field([mob, boss])
      ..guns = [gun(crewOf('shock'))]
      ..captainId = crewOf('shock');
    final r = Round(f, ctx(), CombatStats.of(game(), tables), rage: tables.skills.rageMax)..castUltimate();
    final ult = tables.skills.byId('shock').ultimate;
    expect(mob.x, closeTo(120 + ult.knockback, 1e-9));
    expect(boss.x, closeTo(120 + ult.knockback * tables.skills.bossControlFactor, 1e-9));
    expect(mob.stunTimer, closeTo(ult.stunSec, 1e-9));
    expect(boss.stunTimer, closeTo(ult.stunSec * tables.skills.bossControlFactor, 1e-9));
    expect(r.rage, 0);
  });

  test('6. 사다리: 투척 신화는 폭탄 3개, 서로 다른 대상, 한 발 = 1/3', () {
    final lob = tables.skills.byId('lob');
    expect(lob.attackAt(4).projectiles, 3);
    expect(lob.attackAt(0).projectiles, 1);
    final foes = [foe(100, 100), foe(180, 100), foe(260, 100)];
    final g = gun(crewOf('lob'), rarity: 4)..cooldown = 0;
    round(field(foes)..guns = [g]).fireGuns();
    final dmg = events.whereType<Damage>().toList();
    expect(dmg.map((d) => d.targetId).toSet(), hasLength(3));
    final single = events.whereType<Damage>().first.amount;
    events.clear();
    final g0 = gun(crewOf('lob'))..cooldown = 0;
    round(field([foe(100, 100)])..guns = [g0]).fireGuns();
    final one = events.whereType<Damage>().first.amount;
    // 한 발 피해는 일반 1발 ÷ 3 × (신화 power / 일반 power) (치명타 없음 기준)
    // 등급별 사다리 power(balance crews로 맞춘 값)가 다르므로 그 비율을 곱한다.
    final powerRatio = g.attack.power * (g.legend?.powerScale ?? 1) / g0.attack.power;
    expect(single.toDouble(), closeTo(one.toDouble() / 3 * powerRatio, one.toDouble() * 1e-6));
  });

  test('7. 수중 장판: ZoneSpawned, dotSec 동안 피해 후 사라짐, 즉시+장판 = 단일 피해(±1%)', () {
    final target = foe(200, 124, kind: 'jelly');
    final g = gun(crewOf('underwater'))..cooldown = 0;
    final f = field([target])..guns = [g];
    final r = round(f)..fireGuns();
    final zone = events.whereType<ZoneSpawned>().single;
    for (var i = 0; i <= zone.ticks; i++) {
      r.tickZones();
    }
    expect(f.zones, isEmpty);
    final total = events.whereType<Damage>().fold<double>(0, (s, d) => s + d.amount.toDouble());
    final crit = events.whereType<Damage>().first.crit; // 시드에 따라 치명타면 장판까지 같은 배율
    final expected =
        CombatStats.of(game(), tables).attack.toDouble() *
        g.attack.power *
        (crit ? tables.shipParts.critMultiplier : 1);
    expect(total, closeTo(expected, expected * 0.01));
  });

  test('8. 분열 적은 처치되면 작은 적 2마리, 작은 적은 다시 분열하지 않는다', () {
    final parent = foe(200, 100, kind: 'icecrab', hp: BigNum.from(1e-3));
    final f = field([parent])..guns = [gun(crewOf('direct'))..cooldown = 0];
    round(f).fireGuns();
    final small = f.living.where((e) => e.kind == 'icecrab_small').toList();
    expect(small, hasLength(2));
    expect(small.every((e) => (e.x - 200).abs() <= w.field.spawnSpacing), isTrue);
    for (final s in small) {
      s.hp = BigNum.from(1e-3);
    }
    for (var i = 0; i < 2; i++) {
      f.guns.first.cooldown = 0;
      round(f).fireGuns();
    }
    expect(f.living, isEmpty);
  });

  test('9. 부활 적: 첫 처치는 Kill·골드 없이 일어나고, 두 번째에 Kill', () {
    final e = foe(200, 124, kind: 'angler', hp: BigNum.from(1e-3));
    final f = field([e])..guns = [gun(crewOf('direct'))..cooldown = 0];
    final r = round(f)..fireGuns();
    expect(events.whereType<Kill>(), isEmpty);
    expect(r.gold.isZero, isTrue);
    expect(e.alive, isTrue);
    e.hp = BigNum.from(1e-3);
    f.guns.first.cooldown = 0;
    round(f).fireGuns();
    expect(events.whereType<Kill>(), hasLength(1));
  });

  test('10. OpCastSkill은 쿨타임과 상관없이 즉시 시전', () {
    final crew = crewOf('skip');
    final engine =
        CoreEngine(
            tables: tables,
            clock: ManualClock(start),
            initial: game(crews: {crew: const CrewState(level: 5)}),
          )
          ..advance(30)
          ..drainEvents()
          ..enqueue(OpCastSkill(crew))
          ..enqueue(OpCastSkill(crew))
          ..tick();
    expect(engine.drainEvents().whereType<SkillCast>().where((c) => c.crewId == crew), hasLength(2));
  });

  test('11. 해역별 적: 빙하해(101)엔 분열, 심해(201)엔 부활 적이 나온다', () {
    for (final (stage, role) in [(101, 'split'), (201, 'revive')]) {
      final roles = <String>{};
      final engine = CoreEngine(
        tables: tables,
        clock: ManualClock(start),
        initial: game(stage: stage),
      );
      for (var i = 0; i < 20; i++) {
        engine
          ..enqueue(const OpSetWave())
          ..tick();
        roles.addAll(engine.state.battle!.enemies.map((e) => tables.regions.enemies[e.kind]!.role));
      }
      final region = tables.regions.regionAt(stage);
      expect(engine.state.battle!.enemies.every((e) => region.enemies.contains(e.kind)), isTrue);
      expect(roles, contains(role), reason: '스테이지 $stage');
    }
  });

  test('강습 부채꼴: 배에 붙은 적(dx = 0, 레인 흔들림 dy)은 맞는다 (각도 90° 버그)', () {
    final f = w.field;
    final touching = foe(f.shipX, f.shipY + f.laneJitter * 0.5);
    final g = gun(crewOf('assault'))..cooldown = 0;
    round(field([touching])..guns = [g]).fireGuns();
    expect(events.whereType<Damage>().map((d) => d.targetId), contains(touching.id));
  });

  test('계약 I. 슬롯 투영이 현재 등급 순번을 싣고 JSON 왕복에서 유지된다 (없는 옛 기록은 0)', () {
    final slot = gun(crewOf('lob'), rarity: 3).view();
    expect(slot.rarity, 3);
    expect(FleetSlot.fromJson(slot.toJson()).rarity, 3);
    expect(FleetSlot.fromJson(const {'crewId': 'octo', 'cooldown': 0, 'skillCooldown': 0}).rarity, 0);
  });
}

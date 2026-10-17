import 'dart:convert';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show startBoss;
import 'package:game_core/src/battle/topdown/boss_traits.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 보스 특성 (docs/specs/economy-boss-traits.md 수용 기준 1·2).
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11);
  const stage = 20;
  final regions = jsonDecode(rawTables['regions']!) as Map<String, dynamic>;
  final defaults = regions['bossTraits'] as Map<String, dynamic>;
  final shipRaw = (regions['bosses'] as List).cast<Map<String, dynamic>>().firstWhere((b) => b['id'] == 'enemy_ship');
  // 직사(dodge 대상) · 투척(범위) · 수중(반사막 통과) 선원.
  String crewOf(String family) => t.crews.crews.firstWhere((c) => c.family == family).id;

  ({Round r, Foe boss, List<GameEvent> events, SystemContext ctx}) arena(List<Object> traits) {
    final g = geometryFor(t, stage) as TopGeometry;
    final f = Field(stage: stage, shipHpMax: BigNum.from(1e9), shipHp: BigNum.from(1e9))..geometry = g;
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    final raw = {...shipRaw, 'traits': traits};
    final def = BossDef.fromJson(JsonReader(raw, 'test'), traitDefaults: defaults);
    startBoss(f, stage, ctx, emit: false, x: g.top.shipX, y: g.top.shipY - g.top.bossStandoff, bossDef: def);
    final s = GameState.newGame(playerId: 'b', seed: 1, now: start);
    return (r: Round(f, ctx, CombatStats.of(s, t)), boss: f.foes.firstWhere((e) => e.boss), events: events, ctx: ctx);
  }

  final hit = BigNum.from(1e6);

  test('특성 없는 보스는 그대로(같은 피해, 이벤트 없음)', () {
    final a = arena(const []);
    expect(a.r.traitHit(a.boss, hit, crewId: crewOf('direct')), hit);
    a.r.tickBossTraits();
    expect(a.events, isEmpty);
  });

  test('회피: 단일 탄(직사)은 약 25% MISS(reason evade), 범위(투척)는 늘 맞는다', () {
    final a = arena(const ['evade']);
    var miss = 0;
    for (var i = 0; i < 2000; i++) {
      if (a.r.traitHit(a.boss, hit, crewId: crewOf('direct')) == null) miss++;
    }
    expect(miss / 2000, closeTo(0.25, 0.03));
    expect(a.events.whereType<AttackMissed>().every((m) => m.reason == 'evade'), isTrue);
    for (var i = 0; i < 200; i++) {
      expect(a.r.traitHit(a.boss, hit, crewId: crewOf('lob')), hit);
    }
  });

  test('회피 evadeArea(twister_dolphin): 범위도 피하고 단일은 안 피한다', () {
    final a = arena(const [
      {'type': 'evade', 'chance': 0, 'areaChance': 0.25},
    ]);
    var miss = 0;
    for (var i = 0; i < 2000; i++) {
      if (a.r.traitHit(a.boss, hit, crewId: crewOf('lob')) == null) miss++;
    }
    expect(miss / 2000, closeTo(0.25, 0.03));
    expect(a.r.traitHit(a.boss, hit, crewId: crewOf('direct')), hit);
  });

  test('장갑: 빠른 작은 타격(발사 간격 heavySec 미만)은 × factor, 느리고 센 공격·치명타는 그대로', () {
    final a = arena(const ['armor']);
    a.r.field.guns = [Gun.of(t, 'pang', power: 1), Gun.of(t, 'davy', power: 1)]; // 0.6초 / 7.8초
    expect(a.r.traitHit(a.boss, hit, crewId: 'pang')!.closeTo(hit.times(0.4)), isTrue);
    expect(a.r.traitHit(a.boss, hit, crewId: 'pang', crit: true), hit);
    expect(a.r.traitHit(a.boss, hit, crewId: 'davy'), hit);
  });

  test('HP 보정: 특성 hpFactor의 곱만큼 보스 HP가 줄어든다(평균 처치 시간 유지)', () {
    final plain = arena(const []).boss.maxHp;
    expect((arena(const ['evade', 'reflect']).boss.maxHp / plain).toDouble(), closeTo(0.75 * 0.78, 1e-9));
  });

  test('재생: 초당 최대 HP 1.5%, 기절 중엔 멈춘다', () {
    final a = arena(const ['regen']);
    a.boss.hp = a.boss.maxHp.times(0.5);
    final perTick = 0.015 * a.r.dt;
    a.r.tickBossTraits();
    expect((a.boss.hp / a.boss.maxHp).toDouble(), closeTo(0.5 + perTick, 1e-9));
    a.boss.stunTimer = 1;
    a.r.tickBossTraits();
    expect((a.boss.hp / a.boss.maxHp).toDouble(), closeTo(0.5 + perTick, 1e-9));
  });

  test('재생은 fadeSec 동안 1 → 0으로 줄어 끝나지 않는 보스전이 없다(실기기 6-2 해파리 여왕)', () {
    final a = arena(const ['regen']);
    final fade = a.boss.bossDef!.trait('regen')!.cfg.numberOr('fadeSec', 0);
    expect(fade, greaterThan(0), reason: '표에 fadeSec');
    a.boss.hp = a.boss.maxHp.times(0.5);
    a.r.tickBossTraits(); // 시작 틱 — 아직 전부
    final half = a.ctx.tick + (fade / 2 / a.r.dt).round();
    a.ctx.tick = half;
    final before = (a.boss.hp / a.boss.maxHp).toDouble();
    a.r.tickBossTraits();
    expect((a.boss.hp / a.boss.maxHp).toDouble() - before, closeTo(0.015 * a.r.dt * 0.5, 1e-9), reason: '절반 지나면 절반');
    a.ctx.tick += (fade / a.r.dt).round();
    final late = (a.boss.hp / a.boss.maxHp).toDouble();
    a.r.tickBossTraits();
    expect((a.boss.hp / a.boss.maxHp).toDouble(), late, reason: 'fadeSec 뒤엔 재생 0');
  });

  test('반사막: everySec마다 예고(BossTraitFired) 뒤 sec 동안 피해 0 + 배에 반사, 수중은 통과', () {
    final a = arena(const ['reflect']);
    a.r.tickBossTraits(); // 첫 주기 예약
    final at = a.boss.traitTicks['reflectAt']!;
    for (a.ctx.tick = a.ctx.tick + 1; a.ctx.tick <= at; a.ctx.tick++) {
      a.r.tickBossTraits();
    }
    expect(a.events.whereType<BossTraitFired>().single.trait, 'reflect');
    expect(a.r.traitHit(a.boss, hit, crewId: crewOf('direct')), isNull);
    expect(a.events.whereType<ShipDamaged>(), hasLength(1));
    expect(a.r.traitHit(a.boss, hit, crewId: crewOf('underwater')), hit);
  });

  test('분노: HP 30% 아래로 한 번 — 공격 × 1.3, 쉼 × 0.6', () {
    final a = arena(const ['enrage']);
    final attack = a.boss.attack;
    final rest = a.boss.plan!.restTicks;
    a.boss.hp = a.boss.maxHp.times(0.29);
    a.r
      ..tickBossTraits()
      ..tickBossTraits();
    expect(a.boss.attack.closeTo(attack.times(1.3)), isTrue);
    expect(a.boss.plan!.restTicks, (rest * 0.6).round());
    expect(a.events.whereType<BossTraitFired>().single.trait, 'enrage');
  });

  test('호위: 등장에 3마리(ownerId = 보스), 살아 있으면 보스 피해 × 0.5, HP 50%에 다시 3마리', () {
    final a = arena(const ['escort']);
    a.r.tickBossTraits();
    final guards = a.r.field.foes.where((e) => e.ownerId == a.boss.id).toList();
    expect(guards, hasLength(3));
    expect(a.r.traitHit(a.boss, hit, crewId: crewOf('direct'))!.closeTo(hit.times(0.5)), isTrue);
    a.boss.hp = a.boss.maxHp.times(0.5);
    a.r.tickBossTraits();
    expect(a.r.field.foes.where((e) => e.ownerId == a.boss.id), hasLength(6));
    for (final g in a.r.field.foes.where((e) => e.ownerId == a.boss.id)) {
      g.hp = BigNum.zero;
    }
    expect(a.r.traitHit(a.boss, hit, crewId: crewOf('direct')), hit);
  });

  test('호위는 보스 둘레에 서고, 보스가 쓰러지면 보상 없이 사라진다 · 선원이 아닌 피해(crewId 없음)는 특성을 지나간다', () {
    final a = arena(const ['escort', 'armor']);
    a.r.tickBossTraits();
    final guards = a.r.field.foes.where((e) => e.ownerId == a.boss.id).toList();
    for (final g in guards) {
      final d = math.sqrt(math.pow(g.x - a.boss.x, 2) + math.pow(g.y - a.boss.y, 2));
      expect(d, lessThan(60));
    }
    expect(a.r.traitHit(a.boss, hit), hit);
    a.boss.hp = BigNum.zero;
    a.r.tickBossTraits();
    expect(a.r.field.foes.where((e) => e.ownerId == a.boss.id), isEmpty);
  });

  test('가속: everySec마다 sec 동안 배를 중심으로 deg만큼 돈다(거리 그대로)', () {
    final a = arena(const ['dash']);
    final top = (a.r.geo as TopGeometry).top;
    double angle() => math.atan2(a.boss.y - top.shipY, a.boss.x - top.shipX);
    double dist() => math.sqrt(math.pow(a.boss.x - top.shipX, 2) + math.pow(a.boss.y - top.shipY, 2));
    final d0 = dist();
    final a0 = angle();
    a.r.tickBossTraits();
    final at = a.boss.traitTicks['dashAt']!;
    final sec = (1 / a.r.dt).round();
    for (a.ctx.tick = a.ctx.tick + 1; a.ctx.tick <= at + sec; a.ctx.tick++) {
      a.r.tickBossTraits();
    }
    var turned = (angle() - a0).abs();
    if (turned > math.pi) turned = 2 * math.pi - turned;
    expect(turned, closeTo(math.pi / 2, 0.05));
    expect(dist(), closeTo(d0, 1e-6));
    expect(a.events.whereType<BossTraitFired>().single.trait, 'dash');
  });

  test('표: 약점 표시용 counterFamilies는 특성의 카운터 합', () {
    final croc = t.regions.bosses['sea_croc']!;
    expect(croc.traits.map((x) => x.type), ['armor', 'enrage']);
    expect(croc.counterFamilies, containsAll(['assault', 'laser', 'shock']));
  });
}

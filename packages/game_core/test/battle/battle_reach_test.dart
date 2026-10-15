import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 선원 사거리 (사용자 지시 2026-10-15): 화면 밖 적은 쏘지 않는다. 계열마다 사거리(배 뱃머리에서 x 거리),
/// 선원별 보정(crews.json reachBonus), 모두 보이는 오른쪽 끝(waves.field.visibleRight) 안쪽. 궁극기는 보이는 화면 전체.
void main() {
  final t = GameTables.load();
  final w = t.waves;
  final f = w.field;
  final start = DateTime.utc(2026, 11);

  test('배 위치 shipX 86 (큰 배가 잘리지 않게), 보이는 오른쪽 끝은 필드 안', () {
    expect(f.shipX, 86);
    expect(f.visibleRight, lessThan(f.width));
    expect(f.visibleRight, lessThan(f.spawnX), reason: '적은 화면 밖에서 걸어 들어온다');
  });

  test('모든 계열 공격·계열 스킬·선원 스킬에 사거리, 보정까지 더해도 보이는 끝 안쪽', () {
    final maxBonus = t.crews.crews.map((c) => c.reachBonus).reduce((a, b) => a > b ? a : b);
    for (final fam in t.skills.families) {
      for (final a in [fam.attack, fam.skill.area]) {
        final r = attackReach(a, f);
        expect(r, isNotNull, reason: '${fam.id} reach');
        expect(f.shipX + r! + maxBonus, lessThanOrEqualTo(f.visibleRight), reason: fam.id);
      }
    }
    for (final s in t.skills.crewSkills) {
      expect(attackReach(s.area, f), isNotNull, reason: s.id);
    }
  });

  test('계열 차등: 직사·관통 > 투척 > 강습·충격', () {
    double r(String id) => attackReach(t.skills.byId(id).attack, f)!;
    expect(r('direct'), greaterThan(r('lob')));
    expect(r('pierce'), greaterThan(r('lob')));
    expect(r('lob'), greaterThan(r('assault')));
    expect(r('lob'), greaterThan(r('shock')));
  });

  test('선원별 보정은 작게(±), 같은 계열 안에서도 다르다', () {
    for (final c in t.crews.crews) {
      expect(c.reachBonus.abs(), lessThanOrEqualTo(10), reason: c.id);
    }
    final direct = t.crews.crews.where((c) => c.family == 'direct').map((c) => c.reachBonus).toSet();
    expect(direct.length, greaterThan(1));
  });

  Foe crabAt(double x) => Foe(
    id: x.toInt(),
    kind: 'crab',
    layer: 'surface',
    x: x,
    y: f.shipY,
    maxHp: BigNum.from(1e9),
    speed: 0,
    attack: BigNum.one,
    gold: BigNum.one,
    def: t.regions.enemies['crab'],
  );

  test('eligible: 사거리 경계까지만 (+ 보정)', () {
    final a = t.skills.byId('lob').attack;
    final edge = f.shipX + attackReach(a, f)!;
    expect(eligible(a, [crabAt(edge)], f), hasLength(1));
    expect(eligible(a, [crabAt(edge + 1)], f), isEmpty);
    expect(eligible(a, [crabAt(edge + 1)], f, reachBonus: 2), hasLength(1));
  });

  Round roundWith(List<Foe> foes, String crewId) {
    final s = GameState.newGame(playerId: 'r', seed: 1, now: start);
    final field = Field(stage: 1, shipHpMax: BigNum.from(100), shipHp: BigNum.from(100))
      ..foes.addAll(foes)
      ..guns = [Gun.of(t, crewId, power: 1)];
    return Round(
      field,
      SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: (_) {}),
      CombatStats.of(s, t),
      rage: 0,
    );
  }

  test('사거리 밖 적만 있으면 쏘지 않는다 (화면 밖 폭격 없음)', () {
    final crew = t.crews.crews.firstWhere((c) => c.family == 'lob');
    final edge = f.shipX + attackReach(t.skills.byId('lob').attack, f)! + crew.reachBonus;
    final far = roundWith([crabAt(edge + 5)], crew.id)..fireGuns();
    expect(far.field.foes.single.hp, far.field.foes.single.maxHp);
    final near = roundWith([crabAt(edge - 5)], crew.id)..fireGuns();
    expect(near.field.foes.single.hp < near.field.foes.single.maxHp, isTrue);
  });

  test('궁극기는 보이는 화면 전체 — 그 밖(스폰 대기)은 아니다', () {
    final r = roundWith([crabAt(f.visibleRight - 1), crabAt(f.visibleRight + 10)], 'octo')
      ..field.captainId = 'octo'
      ..rage = t.skills.rageMax;
    expect(r.castUltimate(), isTrue);
    expect(r.field.foes[0].hp < r.field.foes[0].maxHp, isTrue);
    expect(r.field.foes[1].hp, r.field.foes[1].maxHp);
  });

  test('수용 기준: 어떤 선원도 보이는 오른쪽 끝(visibleRight) 밖을 공격하지 않는다 — 강한 함대로 60초', () {
    // 계열마다 한 명씩(같은 계열 상한 안), 최고 등급·강한 배 → 예전에는 화면 밖 적을 먼저 폭격했다.
    final fleet = [for (final fam in t.skills.families) t.crews.crews.firstWhere((c) => c.family == fam.id).id];
    final s0 = GameState.newGame(playerId: 'reach', seed: 3, now: start, crews: fleet).copyWith(
      ship: const ShipState(parts: {'cannon': 120, 'hull': 120, 'sail': 30, 'crowsnest': 45}),
      progress: const Progress(stage: 30, bestStage: 30),
    );
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: s0);
    for (final id in fleet) {
      e.enqueue(OpSetCrew(id, level: 75));
    }
    e.enqueue(OpSetFleet(fleet));
    var fired = 0;
    for (var i = 0; i < 60 * 1000 ~/ w.tickMs; i++) {
      e.tick();
      for (final ev in e.drainEvents()) {
        switch (ev) {
          case AttackFired(:final x, :final crewId):
            fired++;
            expect(x, lessThanOrEqualTo(f.visibleRight), reason: '$crewId 공격 x=$x');
          case SkillCast(:final x, :final crewId):
            expect(x, lessThanOrEqualTo(f.visibleRight), reason: '$crewId 스킬 x=$x');
          default:
        }
      }
    }
    expect(fired, greaterThan(0));
  });
}

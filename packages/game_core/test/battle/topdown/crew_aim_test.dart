import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_aim.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

import '../family_tables.dart';

/// 선원 개성 v2 (docs/specs/platform-crew-identity-v2.md 수용 기준 2~4): 조준 8종, 탄 비행·빗나감, 연사 간격.
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;

  GameTables withAim(Map<String, Map<String, Object?>> aims) {
    final raw = Map<String, String>.of(rawTables);
    final crews = jsonDecode(raw['crews']!) as Map<String, dynamic>;
    // 실제 표의 aim은 지우고(계열 기본에서 시작) 이 테스트가 주는 aim만 넣는다.
    for (final c in (crews['crews'] as List).cast<Map<String, dynamic>>()) {
      c.remove('aim');
      final a = aims[c['id']];
      if (a != null) c['aim'] = a;
    }
    raw['crews'] = jsonEncode(crews);
    final skills = jsonDecode(raw['skills']!) as Map<String, dynamic>;
    for (final fam in (skills['families'] as List).cast<Map<String, dynamic>>()) {
      (fam['attack'] as Map<String, dynamic>).remove('behavior'); // 계열 v3 연출 타이밍(연사 묶음·튕김 지연 등) 없이
    }
    raw['skills'] = jsonEncode(skills);
    return GameTables.load(raw);
  }

  final plain = familyTables(); // 계열 기본(aim·traitScale 없음)
  final s = GameState.newGame(playerId: 'a', seed: 1, now: start).copyWith(
    progress: const Progress(stage: stage, bestStage: stage),
  );

  Foe foe(TopGeometry g, int id, double dx, double dy, {double hp = 100, String layer = 'surface', double speed = 0}) =>
      Foe(
        id: id,
        kind: 'crab',
        layer: layer,
        x: g.top.shipX + dx,
        y: g.top.shipY + dy,
        maxHp: BigNum.from(hp),
        speed: speed,
        attack: BigNum.zero,
        gold: BigNum.one,
        boss: id == 99,
      );

  test('조준 8종: 정해진 첫 대상을 고른다', () {
    final g = geometryFor(plain, stage) as TopGeometry;
    final near = foe(g, 1, 0, -70, hp: 50);
    final far = foe(g, 2, 0, -160, hp: 200);
    final weak = foe(g, 3, 80, -30, hp: 10);
    final bird = foe(g, 4, -70, 50, layer: 'air');
    final boss = foe(g, 99, 0, 140, hp: 150);
    final c1 = foe(g, 5, -60, 120);
    final c2 = foe(g, 6, -54, 124);
    final c3 = foe(g, 7, -62, 128);
    final pool = [near, far, weak, bird, boss, c1, c2, c3];
    final aim = TopAim(g.top, plain.waves);
    Foe pick(String targets) {
      final a = AttackDef.fromJson(JsonReader({'shape': 'single', 'targets': targets}, 't'));
      return aim.pickFirst(a, aim.eligible(a, pool), XorShiftRng(1));
    }

    expect(pick('nearest').id, near.id, reason: 'nearest');
    expect(pick('strongest').id, far.id, reason: 'strongest');
    expect(pick('weakest').id, weak.id, reason: 'weakest');
    expect(pick('boss').id, boss.id, reason: 'boss');
    expect(pick('farthest').id, far.id, reason: 'farthest');
    expect(pick('air').id, bird.id, reason: 'air');
    expect([5, 6, 7], contains(pick('cluster').id));
    expect(pool, contains(pick('random')));
  });

  /// [crewId] 선원 하나로 [seconds] 동안 싸운다(적은 [foes]).
  List<GameEvent> fight(GameTables t, String crewId, List<Foe> Function(TopGeometry) foes, double seconds) {
    final g = geometryFor(t, stage) as TopGeometry;
    final f = Field(stage: stage, shipHpMax: BigNum.from(1e9), shipHp: BigNum.from(1e9))
      ..geometry = g
      ..guns = [Gun.of(t, crewId, power: 1)]
      ..foes.addAll(foes(g));
    final events = <GameEvent>[];
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    final stats = CombatStats.of(s, t);
    final n = (seconds * 1000 / t.waves.tickMs).round();
    for (var i = 0; i < n; i++) {
      ctx.tick = i;
      Round(f, ctx, stats, rage: 0, invincible: true)
        ..moveFoes()
        ..fireGuns()
        ..topdownStep(s);
    }
    return events;
  }

  // 위에서 곧장 내려오는 빠른 적 하나(체력 큼 — 죽지 않게).
  List<Foe> runner(TopGeometry g) => [foe(g, 1, 0, -170, hp: 1000000000000, speed: 40)];

  test('탄 비행: 느린 탄·예측 없음 → 빠른 적에게 빗나감(AttackMissed), 예측이면 맞음, 즉시형은 늘 맞음', () {
    Map<String, Object?> slow({required bool lead}) => {
      'intervalSec': 30, // 한 발만
      'projectile': {'speed': 90, 'lead': lead, 'hitRadius': 4},
    };
    final miss = fight(withAim({'pang': slow(lead: false)}), 'pang', runner, 3);
    final fired = miss.whereType<AttackFired>().single;
    expect(fired.flightTicks, greaterThan(20));
    expect(miss.whereType<AttackMissed>(), hasLength(1));
    expect(miss.whereType<Damage>(), isEmpty);
    final missed = miss.whereType<AttackMissed>().single;
    expect(missed.tick - fired.tick, fired.flightTicks);

    final hit = fight(withAim({'pang': slow(lead: true)}), 'pang', runner, 3);
    expect(hit.whereType<AttackMissed>(), isEmpty);
    expect(hit.whereType<Damage>(), hasLength(1));

    final instant = fight(
      withAim({
        'pang': {'intervalSec': 30},
      }),
      'pang',
      runner,
      3,
    );
    expect(instant.whereType<AttackFired>().single.flightTicks, isNull);
    expect(instant.whereType<Damage>(), hasLength(1));
  });

  test('연사: 0.3초 선원 60초 발사 ≈ 200, 3.0초 ≈ 20 (× 돛 공격 속도)', () {
    List<Foe> target(TopGeometry g) => [foe(g, 1, 0, -80, hp: 1000000000000000)];
    final speed = CombatStats.of(s, plain).attackSpeed;
    int shots(double interval) => fight(
      withAim({
        'pang': {'intervalSec': interval},
      }),
      'pang',
      target,
      60,
    ).whereType<AttackFired>().length;
    // 쏜 뒤 남은 몫을 넘기므로 간격 그대로(틱 올림 없음).
    expect(shots(0.3), closeTo(60 / 0.3 * speed, 2));
    expect(shots(3), closeTo(60 / 3 * speed, 1));
    expect(shots(0.3) / shots(3), greaterThan(8), reason: '연사형은 한 방형의 8배 넘게 쏜다');
  });

  test('연사만 바꾸면 power가 간격에 비례(같은 DPS) — 0.3 : 3.0 = 1 : 10, 등급 사다리 유지, powerScale 곱', () {
    final t = withAim({
      'otter': {'intervalSec': 0.3}, // 같은 계열(물수제비) 둘 — 계열 v3로 투척이 2명이 됐다
      'orca': {'intervalSec': 3.0},
      'octo': {'intervalSec': 1.3, 'powerScale': 1.1},
    });
    for (final r in [0, 3]) {
      final fast = Gun.of(t, 'otter', power: 1, rarity: r).attack;
      final slow = Gun.of(t, 'orca', power: 1, rarity: r).attack;
      expect(fast.power / slow.power, closeTo(0.1, 1e-9), reason: '등급 $r');
      final ladder = Gun.of(plain, 'otter', power: 1, rarity: r).attack;
      expect(fast.power / fast.intervalSec, closeTo(ladder.power / ladder.intervalSec, 1e-9), reason: '같은 DPS');
    }
    final octo = Gun.of(t, 'octo', power: 1).attack;
    final base = Gun.of(plain, 'octo', power: 1).attack;
    expect(octo.power, closeTo(base.power * 1.3 / base.intervalSec * 1.1, 1e-9));
  });

  test('aim 없는 선원은 계열 공격 그대로, 있으면 키만 덮어씀', () {
    final t = withAim({
      'pang': {'intervalSec': 0.3, 'targets': 'weakest'},
    });
    final base = Gun.of(plain, 'pang', power: 1).attack;
    final over = Gun.of(t, 'pang', power: 1).attack;
    expect(over.intervalSec, 0.3);
    expect(over.targets, 'weakest');
    expect(over.shape, base.shape);
    expect(over.raw.raw['reach'], base.raw.raw['reach']);
    expect(Gun.of(t, 'octo', power: 1).attack.raw.raw, Gun.of(plain, 'octo', power: 1).attack.raw.raw);
  });
}

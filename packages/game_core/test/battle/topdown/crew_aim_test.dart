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

/// 선원 개성 v2 (docs/specs/platform-crew-identity-v2.md 수용 기준 2~4): 조준 8종, 탄 비행·빗나감, 연사 간격.
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;

  GameTables withAim(Map<String, Map<String, Object?>> aims) {
    final raw = Map<String, String>.of(rawTables);
    final crews = jsonDecode(raw['crews']!) as Map<String, dynamic>;
    for (final c in (crews['crews'] as List).cast<Map<String, dynamic>>()) {
      final a = aims[c['id']];
      if (a != null) c['aim'] = a;
    }
    raw['crews'] = jsonEncode(crews);
    return GameTables.load(raw);
  }

  final plain = GameTables.load(rawTables);
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

  test('연사: 0.3초 선원 60초 발사 ≈ 200, 3.0초 ≈ 20 (돛 배율 그대로)', () {
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
    // 지금 엔진: 쏜 뒤 쿨다운 = 간격(남은 몫을 넘기지 않음)이라 간격이 틱(0.05초) 단위로 올림되고, 딱 맞는 배수는
    // 부동소수 오차로 한 틱 더 — 0.3초는 실제 0.35초(S2에 알림: v2 균형 때 남은 몫 넘기기로 고칠지).
    final dt = plain.waves.tickMs / 1000;
    double expected(double interval) => 60 / (interval / speed + dt);
    expect(shots(0.3), closeTo(expected(0.3), expected(0.3) * 0.03));
    expect(shots(3), closeTo(expected(3), 2));
    expect(shots(0.3) / shots(3), greaterThan(8), reason: '연사형은 한 방형의 8배 넘게 쏜다');
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

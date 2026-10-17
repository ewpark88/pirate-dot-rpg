import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/crew_traits2.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 선원 정리 2안(BALANCE.md 4절, S1 승인): '탄 +n' 8명 중 5명을 각자 다른 능력으로 —
/// 관통 가속 sword · 부메랑 saw · 물기 속박 bara · 휩쓸기 lobster · 해적왕 강타 davy.
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11);
  final legend = t.rarities.rarities.indexWhere((r) => r.id == 'legend');
  late List<GameEvent> events;
  setUp(() => events = []);

  var nextId = 1;
  Foe foe(double x, double y, {bool boss = false, double speed = 0}) => Foe(
    id: nextId++,
    kind: 'crab',
    layer: 'surface',
    x: x,
    y: y,
    maxHp: BigNum.from(1e12),
    speed: speed,
    attack: BigNum.one,
    gold: BigNum.one,
    boss: boss,
  );

  late Field field;
  Round round(List<Foe> foes) {
    final g = geometryFor(t, 1) as TopGeometry;
    field = Field(stage: 1, shipHpMax: BigNum.from(100), shipHp: BigNum.from(100))
      ..geometry = g
      ..foes.addAll(foes);
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
    return Round(field, ctx, CombatStats.of(GameState.newGame(playerId: 't', seed: 1, now: start), t));
  }

  Gun gun(String id, {int? rarity}) => Gun.of(t, id, power: 1, rarity: rarity ?? legend);
  final base = BigNum.from(1000);
  TopGeometry geo() => geometryFor(t, 1) as TopGeometry;
  List<double> dealt(Foe e) => [
    for (final d in events.whereType<Damage>())
      if (d.targetId == e.id) d.amount.toDouble(),
  ];

  test('표: 다섯 명 모두 탄 +n이 없고 각자 새 능력(신화는 더 세게)', () {
    for (final id in ['sword', 'saw', 'bara', 'lobster', 'davy']) {
      final l = gun(id).legend!;
      expect(l.extraProjectiles, 0, reason: id);
    }
    expect(gun('sword').legend!.pierceRamp, greaterThan(0));
    expect(gun('saw').legend!.boomerang, greaterThan(0));
    expect(gun('bara').legend!.bindSec, greaterThan(0));
    expect(gun('lobster').legend!.sweep, isNotNull);
    expect(gun('davy').legend!.bossBonus, greaterThan(0));
    expect(gun('sword', rarity: legend + 1).legend!.pierceRamp, greaterThan(gun('sword').legend!.pierceRamp));
  });

  test('관통 가속(sword): 꿰뚫을수록 × (1 + ramp)^i — 감쇠가 없다', () {
    final foes = [for (var i = 0; i < 4; i++) foe(geo().top.shipX, geo().top.shipY - 40 - i * 12.0)];
    round(foes);
    final g = gun('sword');
    final v = reshapeVolley(g, (x: 0, y: 0, hits: spread(foes, t.waves, falloff: true)), foes, t.waves, geo());
    final ramp = g.legend!.pierceRamp;
    for (var i = 1; i < v.hits.length; i++) {
      expect(v.hits[i].factor / v.hits[i - 1].factor, closeTo(1 + ramp, 1e-9), reason: '$i');
    }
  });

  test('휩쓸기(lobster): 첫 대상 쪽 부채꼴·거리 안 적만 더한다(뒤쪽·먼 적은 아님)', () {
    final g0 = geo();
    // 강습 reach 22(배 둘레 기준, 배 지킴이) 안 — 앞·옆·뒤 모두 사거리 안, 부채꼴이 가른다.
    final front = foe(g0.top.shipX, g0.top.shipY - 40);
    final side = foe(g0.top.shipX + 12, g0.top.shipY - 40); // 앞쪽 약 17°
    final behind = foe(g0.top.shipX, g0.top.shipY + 40);
    final far = foe(g0.top.shipX, g0.top.shipY - 160);
    final foes = [front, side, behind, far];
    round(foes);
    final v = reshapeVolley(
      gun('lobster'),
      (x: front.x, y: front.y, hits: [(foe: front, factor: 1.0)]),
      foes,
      t.waves,
      geo(),
    );
    final ids = {for (final h in v.hits) h.foe.id};
    expect(ids, containsAll([front.id, side.id]));
    expect(ids, isNot(contains(behind.id)));
    expect(ids, isNot(contains(far.id)));
  });

  test('부메랑(saw): 살아 있는 맞은 적에게 base × boomerang 한 번 더', () {
    final a = foe(100, 100);
    final r = round([a]);
    final g = gun('saw');
    traitsAfterHit(r, g, (x: a.x, y: a.y, hits: [(foe: a, factor: 1.0)]), base);
    expect(dealt(a), [closeTo(1000 * g.legend!.boomerang, 1e-6)]);
  });

  test('물기 속박(bara): 맞은 적이 bindSec 동안 안 움직이고(보스는 bossControlFactor배), 지나면 다시 움직인다', () {
    final g0 = geo();
    final mob = foe(g0.top.shipX, g0.top.shipY - 150, speed: 40);
    final boss = foe(g0.top.shipX + 80, g0.top.shipY - 150, boss: true);
    final r = round([mob, boss]);
    final g = gun('bara');
    traitsAfterHit(r, g, (x: mob.x, y: mob.y, hits: [(foe: mob, factor: 1.0), (foe: boss, factor: 1.0)]), base);
    expect(mob.rootTimer, closeTo(g.legend!.bindSec, 1e-9));
    expect(boss.rootTimer, closeTo(g.legend!.bindSec * t.skills.bossControlFactor, 1e-9));
    final y0 = mob.y;
    final dt = t.waves.tickMs / 1000;
    for (var i = 0; i < (g.legend!.bindSec / dt).floor() - 1; i++) {
      r.ctx.tick++;
      r.moveFoes();
    }
    expect(mob.y, closeTo(y0, 1e-9), reason: '속박 동안 제자리');
    for (var i = 0; i < 10; i++) {
      r.ctx.tick++;
      r.moveFoes();
    }
    expect(mob.y, greaterThan(y0), reason: '풀리면 배 쪽으로');
    expect(mob.rootTimer, 0, reason: '0에서 멈춘다');
    expect(mob.view().rooted, isFalse);
    mob.rootTimer = 1;
    expect(mob.view().rooted, isTrue, reason: 'EnemyView.rooted — 렌더 지속 표시');
    expect(mob.view().toJson()['rooted'], isTrue);
  });

  test('해적왕 강타(davy): 보스·촉수에만 base × bossBonus 더, 잡몹은 그대로', () {
    final boss = foe(100, 100, boss: true);
    final mob = foe(110, 100);
    final r = round([boss, mob]);
    final g = gun('davy');
    traitsAfterHit(r, g, (x: 100, y: 100, hits: [(foe: boss, factor: 1.0), (foe: mob, factor: 1.0)]), base);
    expect(dealt(boss), [closeTo(1000 * g.legend!.bossBonus, 1e-6)]);
    expect(dealt(mob), isEmpty);
  });

  test('결정론: 같은 시드 엔진 2분이면 같은 결과(새 능력은 난수를 안 쓴다)', () {
    String run() {
      final e = CoreEngine(
        tables: t,
        clock: ManualClock(start),
        initial: GameState.newGame(playerId: 'd', seed: 5, now: start).copyWith(
          progress: const Progress(stage: 30, bestStage: 30),
          crews: const {
            'sword': CrewState(level: 50),
            'saw': CrewState(level: 50),
            'bara': CrewState(level: 50),
            'lobster': CrewState(level: 50),
          },
        ),
      );
      for (var i = 0; i < 2400; i++) {
        e
          ..tick()
          ..drainEvents();
      }
      return '${e.state.progress.stage}/${e.state.wallet.gold}/${math.max(0, e.state.progress.wave)}';
    }

    expect(run(), run());
  });
}

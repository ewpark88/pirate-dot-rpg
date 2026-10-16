import 'dart:convert';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_fever.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 피버 오라(사용자 지시 '피버 동안 배가 빠르게 나아가며 주변 적을 녹인다', 표 meta.fever.aura — S2 값 전 테스트 값).
void main() {
  final raw = Map<String, String>.of(rawTables);
  final meta = jsonDecode(raw['meta']!) as Map<String, dynamic>;
  (meta['fever'] as Map<String, dynamic>)['aura'] = {
    'radiusShipMul': 2.5,
    'waveHpPerSec': 0.6,
    'bossFactor': 0.1,
    'pulseSec': 0.25,
    'forwardBoost': 0.5,
  };
  raw['meta'] = jsonEncode(meta);
  final t = GameTables.load(raw);
  final w = t.waves;
  final start = DateTime.utc(2026, 11);
  const stage = 20;

  GameState state({required bool fever}) => GameState.newGame(playerId: 'f', seed: 1, now: start).copyWith(
    progress: const Progress(stage: stage, bestStage: stage),
    battle: BattleView.empty.copyWith(feverTicksLeft: fever ? 100 : 0),
  );

  final geo = geometryFor(t, stage) as TopGeometry;
  final top = geo.top;
  final share = w.mobPoolAt(stage) / w.topMobCountAt(stage);
  final mobHp = BigNum.powOf(w.hpGrowth, stage - 1).times(w.hpBase * w.waveHpPoolFactor * share);

  Foe at(double dist, {bool boss = false, int id = 1}) => Foe(
    id: id,
    kind: 'crab',
    layer: 'surface',
    x: top.shipX + dist,
    y: top.shipY,
    maxHp: boss ? mobHp.times(1000) : mobHp,
    speed: 0,
    attack: BigNum.one,
    gold: BigNum.one,
    boss: boss,
  );

  /// [seconds] 동안 오라만 돌린다.
  void run(Field f, GameState s, double seconds) {
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: (_) {});
    final r = Round(f, ctx, CombatStats.of(s, t), rage: 0);
    for (var i = 0; i < (seconds / r.dt).round(); i++) {
      ctx.tick = i;
      r.feverAura(s);
    }
  }

  Field fieldWith(List<Foe> foes) => Field(stage: stage, shipHpMax: BigNum.from(100), shipHp: BigNum.from(100))
    ..geometry = geo
    ..foes.addAll(foes);

  test('피버 중: 반경(배 반경 × 2.5) 안 잡몹은 waveHpPerSec(0.6초) 남짓에 녹고, 반경 밖은 그대로', () {
    final inside = at(top.shipRadius * 2.5 - 1);
    final outside = at(top.shipRadius * 2.5 + top.mobRadius + 5, id: 2);
    final f = fieldWith([inside, outside]);
    run(f, state(fever: true), 0.5);
    expect(inside.alive, isTrue, reason: '0.5초엔 아직');
    run(f, state(fever: true), 0.3);
    expect(inside.alive, isFalse, reason: '0.6초 남짓이면 녹는다');
    expect(outside.hp.toString(), outside.maxHp.toString());
  });

  test('보스는 × bossFactor(0.1), 피버가 아니면 아무것도 안 한다', () {
    final mob = at(10);
    final boss = at(-10, boss: true, id: 2);
    run(fieldWith([mob, boss]), state(fever: true), 0.25);
    final mobLoss = (mob.maxHp - mob.hp).toDouble();
    final bossLoss = (boss.maxHp - boss.hp).toDouble();
    expect(bossLoss / mobLoss, closeTo(0.1, 1e-6));
    final calm = at(10, id: 3);
    run(fieldWith([calm]), state(fever: false), 1);
    expect(calm.hp.toString(), calm.maxHp.toString());
  });

  test('피버 전진: 배 앞쪽(위)에서 오는 적은 1 + 0.5 × (위쪽 성분)배 빨리, 아래·옆은 그대로', () {
    expect(feverForwardBoost(state(fever: true), meta['fever'] as Map<String, Object?>), 0.5);
    expect(feverForwardBoost(state(fever: false), meta['fever'] as Map<String, Object?>), 0);
    Foe from(double angle) => Foe(
      id: 9,
      kind: 'crab',
      layer: 'surface',
      x: top.shipX + math.cos(angle) * 150,
      y: top.shipY + math.sin(angle) * 150,
      maxHp: BigNum.one,
      speed: 20,
      attack: BigNum.one,
      gold: BigNum.one,
    );
    double moved(double angle, double boost) {
      final e = from(angle);
      final g = TopGeometry(w, top)..forwardBoost = boost;
      final d0 = math.sqrt(math.pow(e.x - top.shipX, 2) + math.pow(e.y - top.shipY, 2));
      g.advance(e, 20, 0.05);
      return d0 - math.sqrt(math.pow(e.x - top.shipX, 2) + math.pow(e.y - top.shipY, 2));
    }

    expect(moved(-math.pi / 2, 0.5) / moved(-math.pi / 2, 0), closeTo(1.5, 1e-9), reason: '바로 위');
    expect(moved(math.pi / 2, 0.5) / moved(math.pi / 2, 0), closeTo(1, 1e-9), reason: '아래');
    expect(moved(0, 0.5) / moved(0, 0), closeTo(1, 1e-9), reason: '옆');
  });
}

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/units.dart';

/// 스테이지 곡선: `base × growth^(stage-1)`.
BigNum stageCurve(double base, double growth, int stage) => BigNum.powOf(growth, stage - 1).times(base);

/// 무리 한 파 (규칙 2). 마리 수 = `mobCountAt(stage)`, 마리당 HP = 단일 HP × `waveHpPoolFactor` × 적 `hpScale`.
/// 적은 오른쪽(`spawnX`)부터 `spawnSpacing` 간격으로 줄지어 들어온다.
void spawnWave(Field f, int stage, SystemContext ctx, {int? count, String? kind}) {
  final t = ctx.tables;
  final w = t.waves;
  final region = t.regions.regionAt(stage);
  final n = count ?? w.mobCountAt(stage);
  final hp = stageCurve(w.hpBase, w.hpGrowth, stage).times(w.waveHpPoolFactor);
  final attack = stageCurve(w.attackBase, w.attackGrowth, stage);
  final gold = stageCurve(w.goldBase, w.goldGrowth, stage);
  for (var i = 0; i < n; i++) {
    final id = kind ?? region.enemies[ctx.rng.nextInt(region.enemies.length)];
    final def = t.regions.enemies[id] ?? t.regions.enemies.values.first;
    f.foes.add(
      Foe(
        id: f.nextId(),
        kind: def.id,
        layer: def.layer,
        x: w.field.spawnX + i * w.field.spawnSpacing,
        y: (w.field.laneY[def.layer] ?? w.field.shipY) + (ctx.rng.nextDouble() - half) * w.field.laneJitter,
        maxHp: hp.times(def.hpScale),
        speed: def.speed,
        attack: attack,
        gold: gold,
        def: def,
        tier: t.regions.tierAt(stage),
      ),
    );
  }
}

/// 보스 등장 (규칙 8, battle-m3-bosses). HP = 단일 HP × `boss.hpMultiplier` × 보스별 배율, 타이머 `boss.timeLimitSec`.
/// 해역 보스 패턴: 보호막은 켠 채로, 크라켄은 촉수와 함께 나온다.
/// 상태 불러오기로 다시 만들 때는 [emit]=false, 남은 HP 비율 [hpRatio]와 위치 [x]를 이어받는다. [hpScale]은 튜토리얼 보스.
void startBoss(
  Field f,
  int stage,
  SystemContext ctx, {
  bool emit = true,
  double hpRatio = 1,
  double? x,
  double hpScale = 1,
}) {
  final t = ctx.tables;
  final w = t.waves;
  final def = t.regions.bossAt(stage);
  final boss = Foe(
    id: f.nextId(),
    kind: def.id,
    layer: 'surface',
    x: x ?? w.field.spawnX,
    y: w.field.laneY['surface'] ?? w.field.shipY,
    maxHp: stageCurve(w.hpBase, w.hpGrowth, stage).times(w.bossHpMultiplier * def.hpMultiplier * hpScale),
    speed: w.bossSpeed,
    attack: stageCurve(w.attackBase, w.attackGrowth, stage).times(w.bossAttackMultiplier),
    gold: stageCurve(w.goldBase, w.goldGrowth, stage).times(w.bossGoldMultiplier),
    boss: true,
    bossDef: def,
    tier: t.regions.tierAt(stage),
  );
  boss.hp = boss.maxHp.times(hpRatio);
  f.foes.add(boss);
  final m = def.mechanic;
  if (m != null) {
    boss.shielded = m.type == 'shield' || m.type == 'tentacles';
    f.bossTimerTicks = (m.intervalSec / (w.tickMs * secondsPerMillisecond)).round();
    for (var i = 0; i < (m.type == 'tentacles' ? m.count : 0); i++) {
      f.foes.add(
        Foe(
          id: f.nextId(),
          kind: '${def.id}_tentacle',
          layer: i.isEven ? 'surface' : 'underwater',
          x: boss.x - (i + 1) * w.field.spawnSpacing,
          y: w.field.laneY[i.isEven ? 'surface' : 'underwater'] ?? w.field.shipY,
          maxHp: boss.maxHp.times(m.hpRatio),
          speed: 0,
          attack: BigNum.zero,
          gold: BigNum.zero,
          ownerId: boss.id,
          tier: boss.tier,
        ),
      );
    }
  }
  f
    ..bossActive = true
    ..bossTicksLeft = bossTimeLimitTicks(ctx)
    ..travelLeft = 0;
  if (emit) ctx.emit(BossSpawned(ctx.tick, kind: def.id, timeLimitTicks: f.bossTicksLeft));
}

/// 보스 제한 시간(초) → 틱.
int bossTimeLimitTicks(SystemContext ctx) =>
    (ctx.tables.waves.bossTimeLimitSec / (ctx.tables.waves.tickMs * secondsPerMillisecond)).round();

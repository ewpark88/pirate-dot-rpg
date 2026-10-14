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
      ),
    );
  }
}

/// 보스 등장 (규칙 8). HP = 단일 HP × `boss.hpMultiplier`, 타이머 `boss.timeLimitSec`.
/// 상태 불러오기로 다시 만들 때는 [emit]=false, 남은 HP 비율 [hpRatio]와 위치 [x]를 이어받는다.
void startBoss(Field f, int stage, SystemContext ctx, {bool emit = true, double hpRatio = 1, double? x}) {
  final t = ctx.tables;
  final w = t.waves;
  final kind = t.regions.regionAt(stage).boss;
  final boss = Foe(
    id: f.nextId(),
    kind: kind,
    layer: 'surface',
    x: x ?? w.field.spawnX,
    y: w.field.laneY['surface'] ?? w.field.shipY,
    maxHp: stageCurve(w.hpBase, w.hpGrowth, stage).times(w.bossHpMultiplier),
    speed: w.bossSpeed,
    attack: stageCurve(w.attackBase, w.attackGrowth, stage).times(w.bossAttackMultiplier),
    gold: stageCurve(w.goldBase, w.goldGrowth, stage).times(w.bossGoldMultiplier),
    boss: true,
  );
  boss.hp = boss.maxHp.times(hpRatio);
  f.foes.add(boss);
  f
    ..bossActive = true
    ..bossTicksLeft = bossTimeLimitTicks(ctx)
    ..travelLeft = 0;
  if (emit) ctx.emit(BossSpawned(ctx.tick, kind: kind, timeLimitTicks: f.bossTicksLeft));
}

/// 보스 제한 시간(초) → 틱.
int bossTimeLimitTicks(SystemContext ctx) =>
    (ctx.tables.waves.bossTimeLimitSec / (ctx.tables.waves.tickMs * secondsPerMillisecond)).round();

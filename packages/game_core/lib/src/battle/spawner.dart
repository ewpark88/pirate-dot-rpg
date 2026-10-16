import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart' show BossDef;

/// 스테이지 곡선: `base × growth^(stage-1)`.
BigNum stageCurve(double base, double growth, int stage) => BigNum.powOf(growth, stage - 1).times(base);

/// 무리 한 파 — 전장 모양([Field.geometry], 탑다운)이 자리를 정한다.
void spawnWave(Field f, int stage, SystemContext ctx, {int? count, String? kind}) =>
    f.geometryOr(ctx.tables.waves).spawnWave(f, stage, ctx, count: count, kind: kind);

/// 무리 한 파의 적들(수치만, 자리는 (0,0) — 전장 모양이 놓는다). 마리 수 = `topMobCountAt`(무리 습격, 2026-10-15),
/// 마리당 HP·공격·골드 = 단일 곡선 × 몫(`mobPoolAt / 마리 수`) — 한 파 총량은 pool 기준 그대로(진행·경제 불변).
/// 운영자 [count](측정 장면)는 몫 없이 마리당 원래 값.
void spawnWaveFoes(Field f, int stage, SystemContext ctx, {int? count, String? kind}) {
  final t = ctx.tables;
  final w = t.waves;
  final region = t.regions.regionAt(stage);
  final n = count ?? w.topMobCountAt(stage);
  final share = count == null ? w.mobPoolAt(stage) / n : 1.0;
  final hp = stageCurve(w.hpBase, w.hpGrowth, stage).times(w.waveHpPoolFactor * share);
  final attack = stageCurve(w.attackBase, w.attackGrowth, stage).times(share);
  final gold = stageCurve(w.goldBase, w.goldGrowth, stage).times(share);
  for (var i = 0; i < n; i++) {
    final id = kind ?? region.enemies[ctx.rng.nextInt(region.enemies.length)];
    final def = t.regions.enemies[id] ?? t.regions.enemies.values.first;
    f.foes.add(
      Foe(
        id: f.nextId(),
        kind: def.id,
        layer: def.layer,
        x: 0,
        y: 0,
        maxHp: hp.times(def.hpScale * f.enemyHpScale),
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
  double? y,
  double hpScale = 1,
  double extraSec = 0,
  BossDef? bossDef,
  BigNum? maxHp,
  bool gold = true,
}) {
  final t = ctx.tables;
  final w = t.waves;
  // 현상금(탑다운 B1): 정해진 보스·체력, 처치 골드 없음([bossDef]·[maxHp]·[gold]). 공격은 [stage] 곡선 그대로.
  final def = bossDef ?? t.regions.bossAt(stage);
  final boss = Foe(
    id: f.nextId(),
    kind: def.id,
    layer: 'surface',
    x: x ?? 0,
    y: y ?? 0,
    maxHp:
        maxHp ??
        stageCurve(
          w.hpBase,
          w.hpGrowth,
          stage,
        ).times(w.bossHpMultiplier * def.hpMultiplier * hpScale * f.enemyHpScale),
    speed: w.bossSpeed,
    attack: stageCurve(w.attackBase, w.attackGrowth, stage).times(w.bossAttackMultiplier),
    gold: gold ? stageCurve(w.goldBase, w.goldGrowth, stage).times(w.bossGoldMultiplier) : BigNum.zero,
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
          x: 0,
          y: 0,
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
  f.geometryOr(w).placeBoss(f, x: x, y: y);
  f
    ..bossActive = true
    ..bossTicksLeft = bossTimeLimitTicks(ctx, extraSec: extraSec)
    ..travelLeft = 0;
  if (emit) ctx.emit(BossSpawned(ctx.tick, kind: def.id, timeLimitTicks: f.bossTicksLeft));
}

/// 보스 제한 시간(초) → 틱.
/// [extraSec]는 보물지도 상점 bossTime.
int bossTimeLimitTicks(SystemContext ctx, {double extraSec = 0}) =>
    ((ctx.tables.waves.bossTimeLimitSec + extraSec) / (ctx.tables.waves.tickMs * secondsPerMillisecond)).round();

/// 첫 회차 초반 보스는 시작 편성으로 잡히게 약하게, 튜토리얼 3단계 첫 보스는 일부러 못 잡게 (설계서 4.12). 재도전은 보통 보스.
double tutorialBossScale(GameState s, SystemContext ctx) {
  final w = ctx.tables.waves;
  final early = s.progress.rebirths == 0 && s.progress.stage <= w.earlyStageMax ? w.earlyHpMultiplier : 1.0;
  final fail = s.tutorialStep == w.tutorialFailStage && s.progress.stage == w.tutorialFailStage
      ? w.tutorialFailHpMultiplier
      : 1.0;
  return early * fail;
}

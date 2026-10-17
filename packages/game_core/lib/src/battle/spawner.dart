import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/boss_patterns.dart' show BossPlan;
import 'package:game_core/src/battle/topdown/top_vanguard.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart' show BossDef, GameTables, WavesTable;

/// 스테이지 곡선: `base × growth^(stage-1)`.
BigNum stageCurve(double base, double growth, int stage) => BigNum.powOf(growth, stage - 1).times(base);

/// 무리 한 파 — 전장 모양([Field.geometry], 탑다운)이 자리를 정한다.
void spawnWave(Field f, int stage, SystemContext ctx, {int? count, String? kind}) {
  final before = f.foes.length;
  f.geometryOr(ctx.tables.waves).spawnWave(f, stage, ctx, count: count, kind: kind);
  if (count == null) addVanguard(f, stage, ctx, f.foes.sublist(before)); // 보통 무리 파만(소환·운영자 제외)
}

/// 무리 한 파의 적들(수치만, 자리는 (0,0) — 전장 모양이 놓는다). 마리 수 = `topMobCountAt`(무리 습격, 2026-10-15),
/// 마리당 HP·공격·골드 = 단일 곡선 × 몫(`mobPoolAt / 마리 수`) — 한 파 총량은 pool 기준 그대로(진행·경제 불변).
/// 운영자 [count](측정 장면)는 몫 없이 마리당 원래 값.
void spawnWaveFoes(Field f, int stage, SystemContext ctx, {int? count, String? kind}) {
  final t = ctx.tables;
  final w = t.waves;
  final region = t.regions.regionAt(stage);
  final n = count ?? (f.feverSwarm != null ? feverSwarmCount(t, stage) : w.topMobCountAt(stage));
  final share = count == null ? w.mobPoolAt(stage) / n : 1.0;
  final hp = stageCurve(w.hpBase, w.hpGrowth, stage).times(w.waveHpPoolFactor * share);
  final attack = stageCurve(w.attackBase, w.attackGrowth, stage).times(share);
  final gold = stageCurve(w.goldBase, w.goldGrowth, stage).times(share);
  for (var i = 0; i < n; i++) {
    final id = kind ?? region.enemies[ctx.rng.nextInt(region.enemies.length)];
    final def = t.regions.enemies[id] ?? t.regions.enemies.values.first;
    final k = def.swarmCount > 0 ? def.swarmCount : 1; // 떼(도감 v2): 한 자리에 k마리, 몫 ÷ k
    for (var j = 0; j < k; j++) {
      final e = Foe(
        id: f.nextId(),
        kind: def.id,
        layer: def.layer,
        x: 0,
        y: 0,
        maxHp: hp.times(def.hpScale * f.enemyHpScale / k),
        speed: def.speed,
        attack: attack.times(1 / k),
        gold: gold.times(1 / k),
        def: def,
        tier: t.regions.tierAt(stage),
      );
      if (def.bomber != null) e.contactTimer = double.infinity; // 자폭: 접촉 공격 대신 박아 터진다(bestiary.dart)
      f.foes.add(e);
    }
  }
}

/// 피버 중 한 파 마리 수 = 평소 × countMul, 상한 max(평소 상한 150보다 크게). 표에 swarm이 없으면 평소 그대로.
/// 몫(pool ÷ 마리 수)은 그대로 나뉘어 한 마리는 약해지고 파 총량(HP·골드·공격)은 변하지 않는다.
/// 피버 중 무리 파의 자리 패턴(표 swarm.pattern). 피버가 아니거나 표에 swarm이 없으면 null.
String? feverSwarmPattern(GameTables t, {required bool fever}) {
  final f = t.meta.raw.obj('fever');
  return fever && f.has('swarm') ? f.obj('swarm').str('pattern') : null;
}

int feverSwarmCount(GameTables t, int stage) {
  final n = t.waves.topMobCountAt(stage);
  final fever = t.meta.raw.obj('fever');
  if (!fever.has('swarm')) return n;
  final sw = fever.obj('swarm');
  final m = (n * sw.number('countMul')).round();
  return m < sw.integer('max') ? m : sw.integer('max');
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
    maxHp: maxHp ?? bossMaxHp(t, stage, def: def, hpScale: hpScale * f.enemyHpScale),
    speed: w.bossSpeed,
    attack: bossAttack(w, stage),
    gold: gold ? stageCurve(w.goldBase, w.goldGrowth, stage).times(w.bossGoldMultiplier) : BigNum.zero,
    boss: true,
    bossDef: def,
    tier: t.regions.tierAt(stage),
  );
  boss.hp = boss.maxHp.times(hpRatio);
  if (def.patterns.isNotEmpty) {
    int ticks(double sec) => (sec / (w.tickMs * secondsPerMillisecond)).round();
    final first = def.firstRestSec;
    boss.plan = BossPlan(def.patterns, ticks(def.restSec), firstTicks: first == null ? null : ticks(first)); // 보스 행동 v2
  }
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

/// 보스 최대 HP = 단일 HP × `boss.hpMultiplier` × 보스별 배율 × 벽 배율 × [hpScale](튜토리얼·보물 바다). 전투와 bossPreview(UI)가 같이 쓴다.
BigNum bossMaxHp(GameTables t, int stage, {BossDef? def, double hpScale = 1}) {
  final w = t.waves;
  final d = def ?? t.regions.bossAt(stage);
  return stageCurve(
    w.hpBase,
    w.hpGrowth,
    stage,
  ).times(w.bossHpMultiplier * d.hpMultiplier * hpScale * wallBossScale(w, stage));
}

/// 보스 한 대 공격력 = 단일 공격 × `boss.attackMultiplier`.
BigNum bossAttack(WavesTable w, int stage) =>
    stageCurve(w.attackBase, w.attackGrowth, stage).times(w.bossAttackMultiplier);

/// 보스 제한 시간(초) → 틱.
/// [extraSec]는 보물지도 상점 bossTime.
int bossTimeLimitTicks(SystemContext ctx, {double extraSec = 0}) =>
    ((ctx.tables.waves.bossTimeLimitSec + extraSec) / (ctx.tables.waves.tickMs * secondsPerMillisecond)).round();

/// 첫 회차 초반 보스는 시작 편성으로 잡히게 약하게, 튜토리얼 3단계 첫 보스는 일부러 못 잡게 (설계서 4.12). 재도전은 보통 보스.
double tutorialBossScale(GameState s, GameTables t) {
  final w = t.waves;
  final early = s.progress.rebirths == 0 && s.progress.stage <= w.earlyStageMax ? w.earlyHpMultiplier : 1.0;
  final fail = s.tutorialStep == w.tutorialFailStage && s.progress.stage == w.tutorialFailStage
      ? w.tutorialFailHpMultiplier
      : 1.0;
  return early * fail;
}

/// 벽 보스 (사용자 '너무 쉽다', 2026-10-16): waves.boss.wallEvery 스테이지마다(해역 보스 자리) 체력 × wallHpMultiplier,
/// midWallEvery마다 × midWallHpMultiplier. 키가 없으면 1.
double wallBossScale(WavesTable w, int stage) {
  final b = w.raw.obj('boss');
  if (b.has('wallEvery') && stage % b.integer('wallEvery') == 0) return b.number('wallHpMultiplier');
  // 중간 벽(선택): midWallEvery 스테이지마다 조금 단단하게 — 보통 스테이지 첫 도전이 늘 성공하지 않게.
  if (b.has('midWallEvery') && stage % b.integer('midWallEvery') == 0) return b.number('midWallHpMultiplier');
  return 1;
}

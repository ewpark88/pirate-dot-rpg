import 'dart:math' as math;

import 'package:game_core/src/battle/captain_skill.dart' show bossBarsAt;
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/boss_patterns.dart' show BossPlan;
import 'package:game_core/src/battle/topdown/top_vanguard.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/fever.dart' show feverOn;
import 'package:game_core/src/economy/formation.dart' show activeFleet;
import 'package:game_core/src/economy/offline.dart' show fleetDps;
import 'package:game_core/src/economy/ship_stats.dart' show shipMaxHp;
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart' show BossDef, GameTables, WavesTable;

/// 보스 크기 배율(waves.top.bossScale[분류], 없으면 1) — 그림(S3)과 엔진(충돌·standoff)이 같은 값을 읽는다.
double bossScaleOf(GameTables t, String bossId) {
  final top = t.waves.raw.obj('top');
  if (!top.has('bossScale')) return 1;
  return top.obj('bossScale').numberOr(t.regions.bossClassOf(bossId), 1);
}

/// 그 보스가 서는 standoff 원 반지름(TopField.standoffOf와 같은 식 — 상태 보기·시나리오용).
double bossStandoffFor(GameTables t, String bossId) {
  final top = t.waves.raw.obj('top');
  final grow = top.has('bossScale') ? top.obj('bossScale').numberOr('standoffGrow', 0) : 0;
  return top.number('bossStandoff') + top.number('bossRadius') * (bossScaleOf(t, bossId) - 1) * grow;
}

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
  final species = t.regions.enemiesAt(stage, rebirths: f.rebirths); // 초반엔 1~2종, 진행·환생으로 늘어난다
  final n = count ?? (f.feverSwarm != null ? feverSwarmCount(t, stage) : w.topMobCountAt(stage));
  final share = count == null || f.scenePooled ? w.mobPoolAt(stage) / n : 1.0; // 장면 파(던전)도 한 파 몫을 나눔
  final hp = stageCurve(w.hpBase, w.hpGrowth, stage).times(w.waveHpPoolFactor * share);
  final attack = stageCurve(w.attackBase, w.attackGrowth, stage).times(share);
  final gold = f.inScene ? BigNum.zero : stageCurve(w.goldBase, w.goldGrowth, stage).times(share); // 탑 등 장면 모드는 골드 없음
  for (var i = 0; i < n; i++) {
    final id = kind ?? species[ctx.rng.nextInt(species.length)];
    final def = t.regions.enemies[id] ?? t.regions.enemies.values.first;
    final k = def.swarmCount > 0 ? def.swarmCount : 1; // 떼(도감 v2): 한 자리에 k마리, 몫 ÷ k
    for (var j = 0; j < k; j++) {
      final e = Foe(
        id: f.nextId(),
        kind: def.id,
        layer: def.layer,
        x: 0,
        y: 0,
        maxHp: hp.times(def.hpScale * f.enemyHpScale * f.sceneHpMul / k),
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
  double? limitSec,
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
    maxHp: maxHp ?? bossMaxHp(t, stage, def: def, hpScale: hpScale * f.enemyHpScale * f.sceneHpMul),
    speed: w.bossSpeed,
    attack: bossAttack(w, stage),
    gold: gold ? stageCurve(w.goldBase, w.goldGrowth, stage).times(w.bossGoldMultiplier) : BigNum.zero,
    boss: true,
    bossDef: def,
    tier: t.regions.tierAt(stage),
  );
  final bars = bossBarsAt(t, stage); // 체력 층(boss-feel) — 불러오기면 남은 HP로 남은 층
  boss
    ..hp = boss.maxHp.times(hpRatio)
    ..scale = bossScaleOf(t, def.id)
    ..bossBars = bars
    ..bossBarsLeft = math.max(1, (hpRatio * bars - 1e-9).ceil());
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
    ..bossTicksLeft = bossTimeLimitTicks(ctx, extraSec: extraSec, limitSec: limitSec)
    ..bossDamage.clear()
    ..travelLeft = 0;
  if (emit) ctx.emit(BossSpawned(ctx.tick, kind: def.id, timeLimitTicks: f.bossTicksLeft));
}

/// 보스 최대 HP = 단일 HP × `boss.hpMultiplier` × 보스별 배율 × 벽 배율 × [hpScale](튜토리얼·보물 바다). 전투와 bossPreview(UI)가 같이 쓴다.
BigNum bossMaxHp(GameTables t, int stage, {BossDef? def, double hpScale = 1}) {
  final w = t.waves;
  final d = def ?? t.regions.bossAt(stage);
  // 보스 특성 보정 hpFactor(특성이 처치를 늦추는 만큼 HP를 줄여 평균 처치 시간을 같게, economy-boss-traits 3절).
  final traits = d.traits.fold<double>(1, (a, x) => a * x.cfg.numberOr('hpFactor', 1));
  return stageCurve(
    w.hpBase,
    w.hpGrowth,
    stage,
  ).times(w.bossHpMultiplier * d.hpMultiplier * hpScale * wallBossScale(w, stage) * traits);
}

/// 보스 한 대 공격력 = 단일 공격 × `boss.attackMultiplier`, 스테이지 1~earlyStageMax는 × earlyAttackMultiplier.
/// (공격은 HP처럼 완만하게 줄이지 않는다 — 시간 제한이 없어 배가 안 가라앉으면 튜토리얼 실패 보스와 끝없이 싸운다.)
BigNum bossAttack(WavesTable w, int stage) => stageCurve(
  w.attackBase,
  w.attackGrowth,
  stage,
).times(w.bossAttackMultiplier * (stage <= w.earlyStageMax ? w.earlyAttackMultiplier : 1));

/// 초반 보스 HP 감쇠: 스테이지 1~earlyStageMax는 [early] 그대로, 그 뒤 `boss.earlyRampToStage`까지 기하급수로 1에 닿는다
/// (S3 첫 15분 점검 2026-10-17 — 스테이지 2 → 3에서 보스 HP가 67배로 뛰는 절벽에 사람식 강화가 7번 실패).
double earlyRamp(WavesTable w, int stage, double early) {
  if (stage <= w.earlyStageMax) return early;
  final to = w.raw.obj('boss').integer('earlyRampToStage');
  if (stage >= to) return 1;
  return math.pow(early, (to - stage) / (to - w.earlyStageMax)).toDouble();
}

/// 보스 제한 시간(초) → 틱.
/// [extraSec]는 보물지도 상점 bossTime.
/// 제한이 0이면(사용자 결정 2026-10-17 '보스 시간을 없애라 — 체력이 떨어질 때까지') 0 = 타이머 없음, 실패는 침몰뿐.
/// [limitSec]은 현상금처럼 따로 시간을 두는 전투(없으면 waves.boss.timeLimitSec).
int bossTimeLimitTicks(SystemContext ctx, {double extraSec = 0, double? limitSec}) {
  final sec = limitSec ?? ctx.tables.waves.bossTimeLimitSec;
  if (sec <= 0) return 0;
  return ((sec + extraSec) / (ctx.tables.waves.tickMs * secondsPerMillisecond)).round();
}

/// 첫 회차 초반 보스는 시작 편성으로 잡히게 약하게, 튜토리얼 3단계 첫 보스는 일부러 못 잡게 (설계서 4.12). 재도전은 보통 보스.
/// 첫 회차 초반 보스 HP 감쇠만([earlyRamp]) — '보스 도전' 버튼(재도전)이 쓴다. 튜토리얼 실패 배율은 첫 만남에만.
double earlyBossScale(GameState s, GameTables t) =>
    s.progress.rebirths == 0 ? earlyRamp(t.waves, s.progress.stage, t.waves.earlyHpMultiplier) : 1.0;

double tutorialBossScale(GameState s, GameTables t) {
  final w = t.waves;
  final early = earlyBossScale(s, t);
  // 튜토리얼 실패 보스(3단계)는 감쇠 없이 × tutorialFailHpMultiplier — 한 번은 꼭 진다(설계서 4.12).
  final step = t.meta.raw.obj('tutorial').obj('steps').integer('boss'); // 단계 번호와 스테이지 번호는 따로 바뀔 수 있다
  // 첫 만남(보스 실패 0번)만 — 실패 뒤 자동 보스·재도전은 일반 보스(안 그러면 방치 플레이어가 튜토리얼 보스에 영원히 진다).
  final fail = s.tutorialStep == step && s.progress.stage == w.tutorialFailStage && s.progress.bossFails == 0;
  return fail ? w.tutorialFailHpMultiplier : early;
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

/// 자동 보스 도전(설정 autoBoss, 방치형 — S3·S4 첫 15분 점검 2026-10-17, S1 규칙 (A)): 실패 뒤 파밍 `cooldownSec`이 지나고
/// **이길 만하면**(retryWinnable) 다음 만남을 보스로 되돌린다(farming false). 이길 만함 = 지금 (함대 DPS × 배 최대 HP)가
/// 실패 때의 1 ÷ (1 − 그때 보스에게 남은 HP 비율)배 이상(최대 `maxNeed`) — 진 판에서 모자랐던 만큼 강화했나.
/// 강화를 안 하는 방치 플레이어도 멈추지 않게 `fallbackSec`이 지나면 그냥 재도전. 튜토리얼 보스 단계도 같다(재도전은 일반 보스).
/// 센 값은 전장(Field)에만 — 세이브에 안 남는다. 남은 틱·이길 만함은 BattleView.autoBossTicksLeft·retryWinnable(화면 신호).
GameState autoBossTick(GameState s, Field f, GameTables t) {
  final p = s.progress;
  if (!p.farming || !s.settings.autoBoss) {
    f
      ..farmTicks = 0
      ..autoBossLeft = 0
      ..retryWinnable = false;
    return s;
  }
  final a = t.waves.raw.obj('boss').obj('autoBoss');
  final perSec = (Duration.millisecondsPerSecond / t.waves.tickMs).round();
  if (f.farmTicks == 0) {
    // 실패 직전 화면(이 틱의 s.battle은 아직 지난 틱 투영)에서 보스에게 남은 HP 비율.
    final left = s.battle?.enemies.where((e) => e.boss).map((e) => e.hpRatio).toList() ?? const <double>[];
    final r = left.isEmpty ? 0.0 : left.reduce(math.max);
    final max = a.number('maxNeed');
    f
      ..failNeed = r >= 1 - 1 / max ? max : 1 / (1 - r)
      ..failPower = retryPower(s, t);
  }
  if (!feverOn(s)) f.farmTicks += 1; // 피버 중엔 쿨다운 멈춤 — 피버 무리 손맛을 끊지 않는다(핵앤슬래시)
  if (f.farmTicks % perSec == 0) f.retryWinnable = retryPower(s, t) >= f.failPower * f.failNeed;
  final cool = (a.number('cooldownSec') * perSec).round();
  final due = f.retryWinnable ? cool : (a.number('fallbackSec') * perSec).round();
  f.autoBossLeft = due - f.farmTicks > 0 ? due - f.farmTicks : 0;
  if (f.autoBossLeft > 0) return s;
  f
    ..farmTicks = 0
    ..autoBossLeft = 0
    ..retryWinnable = false;
  return s.copyWith(progress: p.copyWith(farming: false));
}

/// 재도전 판정용 힘 = 함대 DPS × 배 최대 HP(전투력 fleetPower와 같은 두 축, 지수 없이).
double retryPower(GameState s, GameTables t) =>
    (fleetDps(s, t, activeFleet(s, t)) * shipMaxHp(t.shipParts, s.ship.level('hull'))).toDouble();

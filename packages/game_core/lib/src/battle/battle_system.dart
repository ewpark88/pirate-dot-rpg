import 'package:game_core/src/battle/bosses.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/fleet.dart';
import 'package:game_core/src/battle/legend.dart';
import 'package:game_core/src/battle/skills.dart';
import 'package:game_core/src/battle/spawner.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/cards.dart' show grantBossCards;
import 'package:game_core/src/economy/daily.dart' show addQuestProgress;
import 'package:game_core/src/economy/formation.dart' show activeFleet;
import 'package:game_core/src/economy/rebirth_shop.dart'
    show ShipDressCache, beyondHonor, bossExtraSec, fastSailFraction, treasureHpMultiplier;
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// 전투 규칙: 무리 생성·이동, 자동 발사, 피해, 동시 처치, 함성 게이지·궁극기, 보스 타이머, 파밍 (docs/specs/battle-m1-core.md).
/// 시뮬 내부 값은 [Field]가 들고 매 틱 GameState.battle로 투영한다. 수치는 SystemContext.tables에서만 읽는다.
class BattleSystem implements GameSystem {
  BattleSystem();

  Field? _field;
  Object? _crewsSeen;
  Object? _fleetSeen;
  final _dress = ShipDressCache();
  List<String>? _fixedFleet;
  bool _invincible = false;
  bool _zeroCooldown = false;

  @override
  GameState? handle(GameState state, Command command, SystemContext ctx) {
    switch (command) {
      case ChallengeBoss():
        final f = _sync(state, ctx);
        if (f.bossActive) return state;
        f.foes.clear();
        startBoss(f, state.progress.stage, ctx, extraSec: bossExtraSec(state, ctx.tables));
        return _project(state.copyWith(progress: state.progress.copyWith(farming: false)), f, ctx.tables);
      case TriggerUltimate():
        return _round(state, ctx, (r) => r.castUltimate());
      case OpJumpStage(:final stage):
        _field = null;
        final p = state.progress;
        final s = state.copyWith(
          progress: p.copyWith(stage: stage, wave: 0, farming: false, bestStage: stage > p.bestStage ? stage : null),
        );
        return _project(s, _sync(s, ctx), ctx.tables);
      case OpSetWave(:final count, :final enemyKind):
        final f = _sync(state, ctx)..foes.clear();
        f.bossActive = false;
        spawnWave(f, state.progress.stage, ctx, count: count, kind: enemyKind);
        return _project(state, f, ctx.tables);
      case OpSpawnBoss():
        final f = _sync(state, ctx)..foes.clear();
        startBoss(f, state.progress.stage, ctx, extraSec: bossExtraSec(state, ctx.tables));
        return _project(state, f, ctx.tables);
      case OpSetInvincible(:final on):
        _invincible = on;
        return state;
      case OpCastSkill(:final crewId):
        return _round(state, ctx, (r) {
          final g = r.field.guns.where((g) => g.crewId == crewId).firstOrNull;
          if (g != null) r.castSkill(g);
        });
      case OpZeroCooldown(:final on):
        _zeroCooldown = on;
        return state;
      case OpSetFleet(:final crewIds):
        _fixedFleet = crewIds;
        final f = _sync(state, ctx);
        _arm(f, state, ctx);
        return _project(state, f, ctx.tables);
      default:
        return null;
    }
  }

  @override
  GameState update(GameState state, SystemContext ctx) {
    final next = _round(state, ctx, (r) {
      final f = r.field;
      if (r.t.skills.rageAutoTrigger) r.castUltimate();
      if (f.living.isEmpty && !f.bossActive) {
        f.travelLeft -= r.dt;
        if (f.travelLeft <= 0) _nextEncounter(f, state, ctx);
      }
      r
        ..moveFoes()
        ..tickBoss()
        ..fireGuns()
        ..castSkills()
        ..tickZones()
        ..tickStatus()
        ..tickCombo();
    });
    final after = _resolve(next, _field!, ctx);
    // 보스 처치는 새 Field를 만든다 → _resolve 뒤 다시 읽는다.
    final f = _field!..tick = (state.battle?.tick ?? 0) + 1;
    return _tailwindSpeed(_project(after, f, ctx.tables), ctx);
  }

  /// 무리 다음은 무리, 파를 다 잡았고 파밍 중이 아니면 보스. 빠른 항해: 환생 뒤 bestStage × fastSailFraction(올림) 이하는 rebirthSkip.waves개만.
  void _nextEncounter(Field f, GameState s, SystemContext ctx) {
    final p = s.progress;
    final w = ctx.tables.waves;
    final fast = p.rebirths > 0 && p.stage <= (p.bestStage * fastSailFraction(s, ctx.tables)).ceil();
    if (!p.farming && p.wave >= (fast ? w.rebirthSkip.waves : w.wavesPerStage)) {
      startBoss(f, p.stage, ctx, hpScale: _tutorialBossScale(s, ctx), extraSec: bossExtraSec(s, ctx.tables));
    } else {
      spawnWave(f, p.stage, ctx);
    }
  }

  bool _tailwindBoost = false;

  /// 순풍 중에는 배속을 tailwind.speedMultiplier로(앱이 주기마다 그만큼 틱을 돈다). 운영자 배속(1 아님)은 그대로.
  GameState _tailwindSpeed(GameState s, SystemContext ctx) {
    final b = s.battle;
    if (b == null) return s;
    final until = s.buffs.tailwindUntil;
    final on = until != null && until.isAfter(ctx.clock.now());
    final boost = ctx.tables.ads.placements.firstWhere((p) => p.id == 'tailwind').reward.integer('speedMultiplier');
    if (on && !_tailwindBoost && b.speed == 1) {
      _tailwindBoost = true;
      return s.copyWith(battle: b.copyWith(speed: boost));
    }
    if (!on && _tailwindBoost) {
      _tailwindBoost = false;
      return b.speed == boost ? s.copyWith(battle: b.copyWith(speed: 1)) : s;
    }
    return s;
  }

  /// 첫 회차 초반(1~earlyStageMax) 보스는 입력 없이도 시작 편성으로 잡히게 약하게,
  /// 튜토리얼 3단계의 첫 보스는 일부러 못 잡게 (설계서 4.12). 실패 후 재도전(파밍 → ChallengeBoss)은 보통 보스.
  double _tutorialBossScale(GameState s, SystemContext ctx) {
    final w = ctx.tables.waves;
    final early = s.progress.rebirths == 0 && s.progress.stage <= w.earlyStageMax ? w.earlyHpMultiplier : 1.0;
    final fail = s.tutorialStep == w.tutorialFailStage && s.progress.stage == w.tutorialFailStage
        ? w.tutorialFailHpMultiplier
        : 1.0;
    return early * fail;
  }

  /// 이번 틱 결과로 진행 상태를 바꾼다: 파 정리, 보스 처치·시간 초과, 배 침몰.
  GameState _resolve(GameState s, Field f, SystemContext ctx) {
    final w = ctx.tables.waves;
    final p = s.progress;
    if (f.bossActive) {
      final boss = f.foes.where((e) => e.boss).firstOrNull;
      if (boss != null && !boss.alive) return _bossCleared(s, f, ctx);
      f.bossTicksLeft -= 1;
      if (f.bossTicksLeft <= 0 || f.shipHp.isZero) {
        ctx.emit(BossFailed(ctx.tick, stage: p.stage));
        _restart(f, ctx);
        return s.copyWith(progress: p.copyWith(farming: true, bossFails: p.bossFails + 1));
      }
      return s;
    }
    if (f.shipHp.isZero) {
      // 무리전 침몰: 벌 없이 배를 고치고 이 파를 처음부터.
      _restart(f, ctx);
      return s;
    }
    if (f.foes.isNotEmpty && f.living.isEmpty) {
      f
        ..foes.clear()
        ..travelLeft = w.travelSec;
      final wave = p.wave < w.wavesPerStage ? p.wave + 1 : p.wave;
      ctx.emit(WaveCleared(ctx.tick, wave: wave));
      return s.copyWith(progress: p.copyWith(wave: wave));
    }
    return s;
  }

  GameState _bossCleared(GameState s, Field f, SystemContext ctx) {
    final t = ctx.tables;
    final p = s.progress;
    final stage = p.stage + 1;
    ctx
      ..emit(BossCleared(ctx.tick, stage: p.stage, gems: t.waves.bossGems))
      ..emit(StageAdvanced(ctx.tick, stage: stage));
    if (stage > p.bestStage) ctx.emit(BestStageUpdated(ctx.tick, stage: stage));
    final tier = t.shipTiers.tierAt(stage);
    if (tier.stage == stage && beyondHonor(s, t, tier)) ctx.emit(ShipTierUp(ctx.tick, tierId: tier.id));
    final carded = grantBossCards(s, ctx, [for (final g in f.guns) g.crewId]); // 잡은 스테이지 기준 — 올리기 전에
    ctx.emit(SaveRequested(ctx.tick, reason: 'bossCleared'));
    // 새 스테이지는 빈 바다·가득 찬 배에서 시작한다(옛 뷰의 보스를 이어받지 않게 뷰도 비운다).
    _field = null;
    final old = s.battle ?? BattleView.empty;
    final next = carded.copyWith(
      wallet: carded.wallet.copyWith(gems: carded.wallet.gems + t.waves.bossGems),
      progress: p.copyWith(stage: stage, wave: 0, farming: false, bestStage: stage > p.bestStage ? stage : null),
      // 떠 있던 보물상자는 이어진다(경제 레인이 띄우고 치운다).
      battle: BattleView(
        tick: old.tick,
        shipHp: BigNum.one,
        shipHpMax: BigNum.one,
        hitStopTicks: old.hitStopTicks,
        speed: old.speed,
        chest: old.chest,
      ),
    );
    final nf = _sync(next, ctx)..travelLeft = t.waves.travelSec;
    return _project(next, nf, ctx.tables);
  }

  void _restart(Field f, SystemContext ctx) {
    f
      ..foes.clear()
      ..bossActive = false
      ..bossTicksLeft = 0
      ..shipHp = f.shipHpMax
      ..travelLeft = ctx.tables.waves.travelSec;
  }

  /// 공통: 동기화 → 계산 → 지갑·게이지 반영 → 투영.
  GameState _round(GameState state, SystemContext ctx, void Function(Round) body) {
    final f = _sync(state, ctx);
    final r = Round(
      f,
      ctx,
      CombatStats.of(state, ctx.tables, now: ctx.clock.now()),
      rage: state.progress.rage,
      invincible: _invincible,
      zeroCooldown: _zeroCooldown,
    );
    body(r);
    final counted = r.kills > 0 ? addQuestProgress(state, ctx.tables, 'kill', r.kills) : state;
    final s = counted.copyWith(
      wallet: r.gold.isZero ? null : state.wallet.copyWith(gold: state.wallet.gold + r.gold),
      progress: r.rage == state.progress.rage ? null : state.progress.copyWith(rage: r.rage),
    );
    return _project(s, f, ctx.tables);
  }

  /// 내부 상태가 GameState.battle과 어긋나면(첫 틱, 상태 불러오기, 스테이지 이동, 전장 방식 변경) 새로 만든다.
  Field _sync(GameState s, SystemContext ctx) {
    final view = s.battle ?? BattleView.empty;
    final f = _field;
    if (f != null && f.matches(view, s.progress.stage, s.settings.battleView)) {
      if (!identical(_crewsSeen, s.crews) || !identical(_fleetSeen, s.fleet)) _arm(f, s, ctx);
      return f;
    }
    final stats = CombatStats.of(s, ctx.tables);
    final ratio = view.shipHpMax.isZero ? 1.0 : (view.shipHp / view.shipHpMax).toDouble();
    final nf = Field(stage: s.progress.stage, shipHpMax: stats.shipHp, shipHp: stats.shipHp.times(ratio))
      ..tick = view.tick
      ..geometry = geometryFor(s.settings.battleView, ctx.tables, s.progress.stage)
      ..enemyHpScale = treasureHpMultiplier(s, ctx.tables);
    if (view.bossActive) {
      final b = view.enemies.where((e) => e.boss).firstOrNull;
      startBoss(nf, s.progress.stage, ctx, emit: false, hpRatio: b?.hpRatio ?? 1, x: b?.x, y: b?.y);
      nf.bossTicksLeft = view.bossTicksLeft;
    }
    _field = nf;
    _arm(nf, s, ctx);
    return nf;
  }

  /// 편성(GameState.fleet — 수동 편성, 또는 운영자 고정)과 선장.
  void _arm(Field f, GameState s, SystemContext ctx) {
    _crewsSeen = s.crews;
    _fleetSeen = s.fleet;
    final t = ctx.tables;
    final ids = [
      for (final id in _fixedFleet ?? activeFleet(s, t))
        if (s.crews.containsKey(id)) id,
    ];
    final old = {for (final g in f.guns) g.crewId: (g.cooldown, g.skillCooldown)};
    f
      ..guns = [
        for (final id in ids)
          Gun.of(t, id, power: crewPower(t, s.crews[id]!.level), rarity: rarityIndexAt(t.rarities, s.crews[id]!.level))
            ..cooldown = old[id]?.$1 ?? 0
            ..skillCooldown = old[id]?.$2 ?? 0,
      ]
      ..captainId = captainOf(ids, s, t);
  }

  /// 배 겉모습(외형 단계·등급 그림·스킨·보물 바다)은 ShipDressCache가 채운다.
  GameState _project(GameState s, Field f, GameTables t) => s.copyWith(
    battle: _dress.apply(
      f.view(s.battle ?? BattleView.empty).copyWith(wave: s.progress.wave, rage: s.progress.rage, gold: s.wallet.gold),
      s,
      t,
    ),
  );
}

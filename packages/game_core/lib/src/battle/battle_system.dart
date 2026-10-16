import 'package:game_core/src/battle/bosses.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/fast_sail.dart';
import 'package:game_core/src/battle/fever_strike.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/fleet.dart';
import 'package:game_core/src/battle/legend.dart';
import 'package:game_core/src/battle/skills.dart';
import 'package:game_core/src/battle/spawner.dart';
import 'package:game_core/src/battle/tailwind_speed.dart';
import 'package:game_core/src/battle/topdown/top_bounty.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/cards.dart' show grantBossCards;
import 'package:game_core/src/economy/challenge.dart';
import 'package:game_core/src/economy/daily.dart' show addQuestProgress;
import 'package:game_core/src/economy/fast_sail_supply.dart' show fastSailSupplyLevels;
import 'package:game_core/src/economy/fever.dart' show feverStep;
import 'package:game_core/src/economy/formation.dart' show activeFleet;
import 'package:game_core/src/economy/gold_cap.dart' show addGold;
import 'package:game_core/src/economy/rebirth_shop.dart'
    show ShipDressCache, beyondHonor, bossExtraSec, fastSailFraction, treasureHpMultiplier;
import 'package:game_core/src/economy/sea_events.dart' show startSeaEvent, tapGoldfish;
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// 전투 규칙: 무리 생성·이동, 자동 발사, 피해, 동시 처치, 함성 게이지·궁극기, 보스 타이머, 파밍 (docs/specs/battle-m1-core.md).
class BattleSystem implements GameSystem {
  BattleSystem();

  Field? _field;
  Object? _crewsSeen;
  Object? _fleetSeen;
  final _dress = ShipDressCache();
  final _tailwind = TailwindSpeed();
  static const Map<String, int> Function(GameState, GameTables, int) _supply = fastSailSupplyLevels; // 빠른 항해 보급(S2)
  int _kills = 0;
  final _fun = ChallengeTracker();
  List<String>? _fixedFleet;
  bool _invincible = false;
  bool _zeroCooldown = false;

  @override
  GameState? handle(GameState state, Command command, SystemContext ctx) {
    switch (command) {
      case TapSeaEvent():
        return _project(tapGoldfish(state, _sync(state, ctx), command, ctx), _field!, ctx.tables);
      case OpSeaEvent(:final id):
        return _project(startSeaEvent(state, _sync(state, ctx), ctx, id), _field!, ctx.tables);
      case ChallengeBoss():
        final f = _sync(state, ctx);
        if (f.bossActive) return state;
        f.foes.clear();
        startBoss(f, state.progress.stage, ctx, extraSec: bossExtraSec(state, ctx.tables));
        return _project(state.copyWith(progress: state.progress.copyWith(farming: false)), f, ctx.tables);
      case SkipFastSail():
        final run = _sync(state, ctx).fastSail;
        if (run == null) return state;
        var s = state; // 남은 스테이지마다: 보스 처치 골드 + 보스 격파 보상(젬·카드·배 등급·스테이지)
        while (s.progress.stage <= run.to) {
          s = skipFastSailGold(s, run, ctx.tables);
          s = _bossCleared(s, _field!, ctx);
        }
        return _project(closeFastSail(s, _field!, ctx, skipped: true, supply: _supply), _field!, ctx.tables);
      case RetreatBounty():
        return _project(TopBounty.retreat(state, _sync(state, ctx), ctx), _field!, ctx.tables);
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
    final fresh = _field == null; // 앱을 켜 세이브를 불러온 첫 틱 — 남은 현상금 active는 중단 처리
    final early = TopBounty.prepare(state, _sync(state, ctx), ctx, fresh: fresh);
    if (early != null) return _project(early, _field!..tick = (state.battle?.tick ?? 0) + 1, ctx.tables);
    final next = _round(state, ctx, (r) {
      final f = r.field;
      r.feverStrike(state); // 피버가 시작되는 틱의 첫 일격(궁극기 효과)
      if (f.waveFoes.isEmpty && !f.bossActive) {
        f.travelLeft -= r.dt;
        if (f.travelLeft <= 0) _nextEncounter(f, state, ctx);
      }
      r
        ..moveFoes()
        ..tickBoss()
        ..fireGuns()
        ..castSkills()
        ..tickZones()
        ..topdownStep(state)
        ..tickStatus()
        ..tickCombo()
        ..breakthrough(state); // 빠른 항해 돌파(fast_sail.dart)
    });
    if (_field!.bounty != null) {
      return _project(TopBounty.resolve(next, _field!..tick = (state.battle?.tick ?? 0) + 1, ctx), _field!, ctx.tables);
    }
    final resolved = _resolve(next, _field!, ctx);
    final f = _field!..tick = (state.battle?.tick ?? 0) + 1;
    final sailing = f.fastSail != null; // 돌파 중엔 이벤트·도전·피버 없음
    final after = sailing ? resolved : _fun.step(resolved, f, ctx, kills: _kills);
    final boss = after.progress.stage > next.progress.stage; // 보스 처치 = 스테이지가 올랐다
    final shown = _tailwind.apply(_project(closeFastSail(after, f, ctx, supply: _supply), f, ctx.tables), ctx);
    return sailing ? shown : feverStep(shown, ctx, kills: _kills, bossKilled: boss);
  }

  /// 무리 다음은 무리, 파를 다 잡았고 파밍 중이 아니면 보스. 빠른 항해: 환생 뒤 bestStage × fastSailFraction(올림) 이하는 rebirthSkip.waves개만.
  void _nextEncounter(Field f, GameState s, SystemContext ctx) {
    final p = s.progress;
    final w = ctx.tables.waves;
    final fast = p.rebirths > 0 && p.stage <= (p.bestStage * fastSailFraction(s, ctx.tables)).ceil();
    if (!p.farming && p.wave >= (fast ? w.rebirthSkip.waves : w.wavesPerStage)) {
      startBoss(f, p.stage, ctx, hpScale: tutorialBossScale(s, ctx), extraSec: bossExtraSec(s, ctx.tables));
    } else {
      spawnWave(f, p.stage, ctx);
    }
  }

  GameState _resolve(GameState s, Field f, SystemContext ctx) {
    final w = ctx.tables.waves;
    final p = s.progress;
    if (f.bossActive) {
      final bosses = f.foes.where((e) => e.boss); // 분열하면 여럿 — 모두 쓰러져야 격파(도감 v2)
      if (bosses.isNotEmpty && bosses.every((e) => !e.alive)) return _bossCleared(s, f, ctx);
      f.bossTicksLeft -= 1;
      if (f.bossTicksLeft <= 0 || f.shipHp.isZero) {
        ctx.emit(BossFailed(ctx.tick, stage: p.stage));
        _restart(f, ctx);
        return s.copyWith(progress: p.copyWith(farming: true, bossFails: p.bossFails + 1));
      }
      return s;
    }
    if (f.shipHp.isZero) {
      _restart(f, ctx);
      return s;
    }
    if (f.foes.any((e) => e.eventKind == null) && f.waveFoes.isEmpty) {
      f
        ..foes.removeWhere((e) => e.eventKind == null)
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
    final gems = stage > p.bestStage ? t.waves.bossGems : 0; // 처음 깬 보스만(사용자 신고 '젬 과다', 환생 뒤 반복은 없음)
    ctx
      ..emit(BossCleared(ctx.tick, stage: p.stage, gems: gems))
      ..emit(StageAdvanced(ctx.tick, stage: stage));
    if (stage > p.bestStage) ctx.emit(BestStageUpdated(ctx.tick, stage: stage));
    final tier = t.shipTiers.tierAt(stage);
    if (tier.stage == stage && beyondHonor(s, t, tier)) ctx.emit(ShipTierUp(ctx.tick, tierId: tier.id));
    final carded = grantBossCards(s, ctx, [for (final g in f.guns) g.crewId]); // 잡은 스테이지 기준 — 올리기 전에
    ctx.emit(SaveRequested(ctx.tick, reason: 'bossCleared'));
    _field = null;
    final old = s.battle ?? BattleView.empty;
    final next = carded.copyWith(
      wallet: carded.wallet.copyWith(gems: carded.wallet.gems + gems),
      progress: p.copyWith(stage: stage, wave: 0, farming: false, bestStage: stage > p.bestStage ? stage : null),
      battle: BattleView(
        tick: old.tick,
        shipHp: BigNum.one,
        shipHpMax: BigNum.one,
        hitStopTicks: old.hitStopTicks,
        speed: old.speed,
        chest: old.chest,
      ),
    );
    final nf = _sync(next, ctx)
      ..travelLeft = t.waves.travelSec
      ..fastSail = f.fastSail; // 돌파 구간은 새 전장으로 이어간다
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
    _kills = r.kills;
    final counted = r.kills > 0 ? addQuestProgress(state, ctx.tables, 'kill', r.kills) : state;
    final paid = addGold(counted, ctx.tables, r.gold); // 화물칸 용량까지
    _fun.overflow(paid.lost, ctx);
    final s = paid.state.copyWith(
      progress: r.rage == state.progress.rage ? null : state.progress.copyWith(rage: r.rage),
    );
    return _project(s, f, ctx.tables);
  }

  /// 내부 상태가 GameState.battle과 어긋나면(첫 틱, 상태 불러오기, 스테이지 이동) 새로 만든다.
  Field _sync(GameState s, SystemContext ctx) {
    final view = s.battle ?? BattleView.empty;
    final f = _field;
    if (f != null && f.matches(view, s.progress.stage)) {
      if (!identical(_crewsSeen, s.crews) || !identical(_fleetSeen, s.fleet)) _arm(f, s, ctx);
      shapeField(f, s, ctx.tables); // 선체 강화로 배가 커지면 모양만 바꾼다(무리는 그대로)
      return f;
    }
    final stats = CombatStats.of(s, ctx.tables);
    final ratio = view.shipHpMax.isZero ? 1.0 : (view.shipHp / view.shipHpMax).toDouble();
    final nf = Field(stage: s.progress.stage, shipHpMax: stats.shipHp, shipHp: stats.shipHp.times(ratio))
      ..tick = view.tick
      ..enemyHpScale = treasureHpMultiplier(s, ctx.tables);
    shapeField(nf, s, ctx.tables);
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

  GameState _project(GameState s, Field f, GameTables t) => s.copyWith(
    battle: _dress.apply(
      f.view(s.battle ?? BattleView.empty).copyWith(wave: s.progress.wave, rage: s.progress.rage, gold: s.wallet.gold),
      s,
      t,
    ),
  );
}

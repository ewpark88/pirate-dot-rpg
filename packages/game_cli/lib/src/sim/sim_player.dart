import 'package:game_cli/src/sim/sim_cards.dart';
import 'package:game_cli/src/sim/sim_fun.dart';
import 'package:game_cli/src/sim/sim_gold.dart';
import 'package:game_cli/src/sim/sim_result.dart';
import 'package:game_cli/src/sim/sim_threat.dart';
import 'package:game_cli/src/sim/sim_upgrades.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';

export 'package:game_cli/src/sim/sim_result.dart';

/// 설계서 7.2의 가상 플레이어: 가장 싼 강화·소환·합치기·승급, 보스 실패 시 farmRetrySec 파밍 후 재도전. 실제 엔진을 돌린다.
class SimPlayer {
  SimPlayer(this.t, {required this.seed, this.bossAd = false, String view = 'top'}) : clock = ManualClock(_start) {
    final fresh = GameState.newGame(playerId: 'sim$seed', seed: seed, now: _start, crews: t.meta.startingCrews);
    final initial = view == 'top' ? fresh : fresh.copyWith(settings: Settings(battleView: view));
    engine = CoreEngine(tables: t, clock: clock, initial: initial);
    result = SimResult(seed);
    final sim = t.meta.raw.obj('sim');
    decisionTicks = (sim.number('decisionSec') * Duration.millisecondsPerSecond / t.waves.tickMs).round();
    farmRetry = Duration(milliseconds: (sim.number('farmRetrySec') * Duration.millisecondsPerSecond).round());
  }

  static final _start = DateTime.utc(2026, 11);

  final GameTables t;
  final int seed;

  final bool bossAd;
  final ManualClock clock;
  late final CoreEngine engine;
  late final SimResult result;
  late final int decisionTicks;
  late final Duration farmRetry;

  Duration _elapsed = Duration.zero;

  Duration _online = Duration.zero;
  Duration? _farmSince;
  int _upgradesAtFarm = 0;

  static const _tutorialRetryUpgrades = 2;
  Duration? _wallSince;

  ({Duration at, int stage})? _recovering;

  Duration _runStart = Duration.zero;

  int _best = 1;

  ({Duration at, int stage})? _beatTarget;
  Object? _crewsSeen;
  Duration? _lastBoss;
  var _reached = <int, Duration>{};
  var _prevReached = <int, Duration>{};
  Duration? _lastWave;
  Map<String, int> _rarityIndex = const {};
  final _waveGaps = <(Duration at, Duration gap)>[];
  final _killGold = <(Duration at, BigNum gold)>[];
  late final _fun = SimFun(t);
  late final _threat = SimThreat(t);
  final _gold = SimGold();

  SimResult run(Duration total, SimSchedule first) {
    var schedule = first;
    final tick = Duration(milliseconds: t.waves.tickMs);
    while (_elapsed < total) {
      final sessionEnd = _elapsed + schedule.online;
      while (_elapsed < total && _elapsed < sessionEnd) {
        if (engine.state.battle != null && (_elapsed.inMilliseconds ~/ tick.inMilliseconds) % decisionTicks == 0) {
          _decide();
        }
        engine.tick();
        clock.advance(tick);
        _elapsed += tick;
        _online += tick;
        _observe(engine.drainEvents());
      }
      if (schedule.offline > Duration.zero && _elapsed < total) _goOffline(schedule.offline);
      schedule = schedule.then ?? first;
    }
    return _finish();
  }

  void _goOffline(Duration away) {
    engine
      ..enqueue(OpLoadState(engine.state.copyWith(savedAt: clock.now())))
      ..tick()
      ..drainEvents();
    clock.advance(away);
    _elapsed += away;
    _lastWave = null;
    engine.enqueue(const ClaimOffline());
  }

  void _decide() {
    final s = engine.state;
    final now = {for (final e in s.crews.entries) e.key: promotionCount(t.rarities, e.value.level)};
    if (now.entries.any((e) => e.value > (_rarityIndex[e.key] ?? e.value))) result.firstRarityUp ??= _elapsed;
    final starter = t.growth.bossCards.starterCrew;
    if ((now[starter] ?? 0) > (_rarityIndex[starter] ?? 0)) result.starterPromotion ??= _elapsed;
    _rarityIndex = now;
    if (canSummon(s, t, 1) || canSummon(s, t, t.meta.raw.obj('tutorial').integer('firstTenCount'))) {
      result.firstSummonReady ??= _elapsed;
    }

    engine.enqueue(const MergeAllCards());
    if (s.battle?.chest != null) engine.enqueue(const TapChest());
    for (final id in s.crews.keys) {
      if (canPromote(s, t, id)) engine.enqueue(PromoteCrew(id));
    }
    for (final n in const [10, 1]) {
      if (canSummon(s, t, n)) {
        engine.enqueue(Summon(count: n));
        result.summons += n;
        result.cardsByRun.last.summons += n;
        break;
      }
    }
    result.upgrades += _gold.decide(buyCheapest(engine, t, s), _online, s.progress, isFull: cargoBlocked(t, s));
    buyRebirthShop(engine, t, s);
    // 수동 편성(ADR-0010): 가상 플레이어는 선원이 바뀔 때마다 ‘자동 편성’ 버튼을 누른다.
    if (!identical(s.crews, _crewsSeen)) {
      _crewsSeen = s.crews;
      engine.enqueue(const AutoFleet());
    }
    // 튜토리얼: UI 확인 단계(첫 연출·소환 결과·마지막 말풍선)는 바로 넘긴다. 나머지는 코어가 판정.
    final step = s.tutorialStep;
    final acks = t.meta.raw.obj('tutorial').obj('steps').raw['ack'] as List;
    if (step != null && acks.contains(step)) engine.enqueue(TutorialAck(step));

    if (_shouldRebirth(s)) {
      engine
        ..enqueue(const Rebirth())
        ..enqueue(const StartVoyage()); // 환생 지도 '출항!'을 바로 누른다(#19 — 지금 결과와 같게)
      _endWall();
      _farmSince = null;
      _recovering = (at: _online, stage: (s.progress.stage * t.meta.rebirth.number('recoverTargetRatio')).ceil());
      result.rebirths++;
      if (result.firstRebirth == null) {
        _beatTarget = (at: _online, stage: s.progress.stage);
        result.rebirthForecastMin = rebirthForecast(s, t)?.minutesRaw;
      }
      result.firstRebirth ??= _elapsed;
      result.firstRebirthStage ??= s.progress.stage;
      result.rebirthStages.add(s.progress.stage);
      result.cardsByRun.add(RunCards());
      _prevReached = _reached;
      _reached = {};
      _runStart = _online;
      return;
    }
    if (s.progress.farming) {
      // 튜토리얼 보스 단계(설계서 4.12 3단계 ‘강화 2번 후 보스 도전’)에서는 실패 뒤 강화 2번이면 바로 재도전.
      final tutorialBoss = s.tutorialStep == t.meta.raw.obj('tutorial').obj('steps').integer('boss');
      if (_farmSince == null) {
        if (bossAd && !tutorialBoss && canWatchAd(s, t, AdPlacement.bossSupport)) {
          engine
            ..enqueue(const GrantAdReward(AdPlacement.bossSupport))
            ..enqueue(const ChallengeBoss());
          result.bossAds++;
          return;
        }
        _farmSince = _elapsed;
        _upgradesAtFarm = result.upgrades;
      }
      if ((tutorialBoss && result.upgrades - _upgradesAtFarm >= _tutorialRetryUpgrades) ||
          _elapsed - _farmSince! >= farmRetry) {
        engine.enqueue(const ChallengeBoss());
        _farmSince = null;
      }
    } else {
      _farmSince = null;
    }
  }

  bool _shouldRebirth(GameState s) {
    final since = _wallSince;
    return since != null &&
        s.progress.stage >= t.meta.rebirth.integer('minStage') &&
        (_online - since).inSeconds >= t.meta.raw.obj('sim').number('rebirthWallSec');
  }

  void _endWall() {
    final since = _wallSince;
    if (since != null && _online - since > result.wallMax) result.wallMax = _online - since;
    _wallSince = null;
  }

  void _recordLook(Map<String, int> best, Duration within, String part, int stage) {
    if (_elapsed <= within && stage > (best[part] ?? 0)) best[part] = stage;
  }

  void _observe(List<GameEvent> events) {
    for (final e in events) {
      _fun.observe(e, engine);
      _threat.observe(e, engine);
      switch (e) {
        case Kill(:final gold):
          _killGold.add((_elapsed, gold));
        case WaveCleared():
          final last = _lastWave;
          if (last != null) _waveGaps.add((_elapsed, _elapsed - last));
          _lastWave = _elapsed;
        case BossCleared(:final stage):
          final lastBoss = _lastBoss;
          if (_recovering != null && lastBoss != null) {
            result.recoverBossGaps.add((_online - lastBoss).inMilliseconds / Duration.millisecondsPerSecond);
          }
          _lastBoss = _recovering != null ? _online : null;
          result.cardsByRun.last.bossCleared(t, stage: stage, bestBefore: _best, rebirths: result.rebirths);
          if (stage + 1 > _best) _best = stage + 1;
        case PartUpgraded(:final part, :final level):
          _recordLook(result.levelDay1, const Duration(days: 1), part, level);
          _recordLook(result.levelWeek1, const Duration(days: 7), part, level);
        case ShipLookChanged(:final part, :final stage):
          _recordLook(result.lookDay1, const Duration(days: 1), part, stage);
          _recordLook(result.lookWeek1, const Duration(days: 7), part, stage);
        case BossFailed(:final stage):
          result.firstBossFail ??= _elapsed;
          result.firstBossFailStage ??= stage;
          _wallSince ??= _online;
        case StageAdvanced(:final stage):
          final beat = _beatTarget;
          if (beat != null && stage > beat.stage) {
            result.rebirthBeatBest = _online - beat.at;
            _beatTarget = null;
          }
          if (stage >= 10) result.stage10 ??= _elapsed;
          if (stage >= 40) result.stage40 ??= _elapsed;
          _endWall();
          _lastWave = _elapsed;
          _reached[stage] ??= _online - _runStart;
          final rec = _recovering;
          if (rec != null && stage >= rec.stage) {
            final took = _online - rec.at;
            final worst = result.rebirthRecoverMax;
            if (worst == null || took > worst) result.rebirthRecoverMax = took;
            final before = _prevReached[rec.stage];
            if (before != null && before > Duration.zero) {
              final ratio = took.inMilliseconds / before.inMilliseconds;
              final w = result.rebirthRecoverRatioMax;
              if (w == null || ratio > w) result.rebirthRecoverRatioMax = ratio;
            }
            _recovering = null;
          }
        case CrewPromoted(:final rarity):
          if (rarity == 'legend') result.firstLegendPromoted ??= _elapsed;
          if (rarity == 'mythic') result.firstMythic ??= _elapsed;
        default:
      }
    }
    final legendMin = t.rarities.byId('legend').levelMin;
    if (result.firstLegendOwned == null && engine.state.crews.values.any((c) => c.level >= legendMin)) {
      result.firstLegendOwned = _elapsed;
    }
  }

  SimResult _finish() {
    final s = engine.state;
    final since = _wallSince;
    if (since != null && _online - since > result.wallMax) result.wallMax = _online - since;
    double avg(Iterable<Duration> xs) =>
        xs.isEmpty ? 0 : xs.fold(0, (a, d) => a + d.inMilliseconds) / xs.length / Duration.millisecondsPerSecond;
    const early = Duration(minutes: 10);
    final recent = [
      for (final (at, g) in _killGold)
        if (at > _elapsed - early) g,
    ];
    final estimate = goldPerSecEstimate(s, t, offlineFleet(s, t));
    result
      ..mapPieces = s.wallet.mapPieces
      ..eventGoldPct = _fun.eventGoldPct
      ..challengeWinPct = _fun.challengeWinPct
      ..feverIntervalMin = _fun.fevers == 0 ? null : _online.inSeconds / Duration.secondsPerMinute / _fun.fevers
      ..feverGoldPct = _fun.feverGoldPct
      ..overflowPct = _fun.overflowPct
      ..threat = _threat
      ..goldSupply = _gold
      ..wallSinkSec = SimThreat.median(_threat.sinkSec)
      ..farmWaveDamagePct = _threat.farmWaveDamagePct
      ..waveSecFirst10Min = avg([
        for (final (at, gap) in _waveGaps)
          if (at <= early) gap,
      ])
      ..waveSecAll = avg([for (final (_, gap) in _waveGaps) gap])
      ..goldPerSecActual = recent.fold(BigNum.zero, (a, g) => a + g) / BigNum.from(early.inSeconds)
      ..goldPerSecEstimated = estimate
      ..played = _elapsed
      ..bestStage = s.progress.bestStage
      ..gold = s.wallet.gold
      ..gems = s.wallet.gems
      ..offline8hUpgrades = upgradesAffordable(
        t,
        s.ship.parts,
        estimate.times(t.meta.offlineMaxSec * t.meta.offlineEfficiency),
      );
    return result;
  }
}

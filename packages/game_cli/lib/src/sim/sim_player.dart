import 'package:game_cli/src/sim/sim_upgrades.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';

/// 가상 플레이어 한 명의 결과. 시간은 모두 게임 시작부터의 경과(오프라인 포함).
class SimResult {
  SimResult(this.seed);

  final int seed;
  Duration played = Duration.zero;
  Duration? firstBossFail;
  Duration? firstSummonReady;
  Duration? stage10;
  Duration? stage40;

  /// 이미 보유한 선원의 등급이 처음 오른 시점 (승급·높은 등급 카드 점프 모두, 설계서 4.3.3 ‘첫 승급’).
  Duration? firstRarityUp;

  /// 튜토리얼 선원(`bossCards.starterCrew`, 옥토)의 첫 승급 — 운과 상관없는 첫 승급(설계서 4.3.3).
  Duration? starterPromotion;
  Duration? firstLegendOwned;
  Duration? firstLegendPromoted;
  Duration? firstMythic;
  Duration wallMax = Duration.zero;
  int bestStage = 1;

  /// 파 처치 간격(초) 평균 — 처음 10분 / 전체. 전투 테이블 조정용(S1 요청).
  double waveSecFirst10Min = 0;
  double waveSecAll = 0;
  int summons = 0;
  int upgrades = 0;
  BigNum gold = BigNum.zero;
  int gems = 0;

  /// 마지막 10분(접속 중) 실제 초당 처치 골드와 끝 상태의 오프라인 추정치. 추정식 보정용.
  BigNum goldPerSecActual = BigNum.zero;
  BigNum goldPerSecEstimated = BigNum.zero;

  /// 끝 상태에서 오프라인 8시간 보상으로 살 수 있는 ‘가장 싼 강화’ 횟수.
  int offline8hUpgrades = 0;

  /// 환생 (스펙 economy-rebirth 규칙 8): 횟수, 첫 환생, 환생 뒤 이전 스테이지의 recoverTargetRatio까지 걸린 가장 긴 시간.
  int rebirths = 0;
  int mapPieces = 0;
  Duration? firstRebirth;
  Duration? rebirthRecoverMax;
}

/// 접속 일정. [online]마다 [offline]만큼 쉰다. [offline]이 0이면 계속 접속.
/// [then]이 있으면 다음 접속은 그 일정을 따르고, 마지막 뒤에는 처음으로 돌아간다.
class SimSchedule {
  const SimSchedule({required this.online, this.offline = Duration.zero, this.then});

  /// 설계서 4.3.3 기준 하루: 20분 접속 → 8시간 오프라인 → 20분 접속 → 나머지(15시간 20분) 오프라인.
  static const daily = SimSchedule(
    online: Duration(minutes: 20),
    offline: Duration(hours: 8),
    then: SimSchedule(online: Duration(minutes: 20), offline: Duration(hours: 15, minutes: 20)),
  );

  final Duration online;
  final Duration offline;
  final SimSchedule? then;
}

/// 설계서 7.2의 가상 플레이어: 가장 싼 강화 구매, 젬이 모이면 소환, 합치기·승급,
/// 보스 실패 시 `meta.sim.farmRetrySec` 파밍 후 재도전. 실제 엔진(CoreEngine)을 돌린다.
class SimPlayer {
  SimPlayer(this.t, {required this.seed}) : clock = ManualClock(_start) {
    final initial = GameState.newGame(playerId: 'sim$seed', seed: seed, now: _start, crews: t.meta.startingCrews);
    engine = CoreEngine(tables: t, clock: clock, initial: initial);
    result = SimResult(seed);
    final sim = t.meta.raw.obj('sim');
    decisionTicks = (sim.number('decisionSec') * Duration.millisecondsPerSecond / t.waves.tickMs).round();
    farmRetry = Duration(milliseconds: (sim.number('farmRetrySec') * Duration.millisecondsPerSecond).round());
  }

  static final _start = DateTime.utc(2026, 11);

  final GameTables t;
  final int seed;
  final ManualClock clock;
  late final CoreEngine engine;
  late final SimResult result;
  late final int decisionTicks;
  late final Duration farmRetry;

  Duration _elapsed = Duration.zero;

  /// 접속 중 시간만 (벽·환생 회복은 플레이 시간 기준 — 설계서 4.5·7.2).
  Duration _online = Duration.zero;
  Duration? _farmSince;
  Duration? _wallSince;

  /// 환생 뒤 회복 측정 중: 환생 시각과 목표 스테이지.
  ({Duration at, int stage})? _recovering;
  Duration? _lastWave;
  Map<String, int> _rarityIndex = const {};
  final _waveGaps = <(Duration at, Duration gap)>[];
  final _killGold = <(Duration at, BigNum gold)>[];

  /// 일정대로 [total]만큼 (오프라인 포함) 돈다.
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
    // 앱이 꺼질 때 저장 = savedAt 갱신. 돌아오면 복귀 보상.
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
        break;
      }
    }
    _buyCheapest(s);
    // 튜토리얼: UI 확인 단계(첫 연출·소환 결과·마지막 말풍선)는 바로 넘긴다. 나머지는 코어가 판정.
    final step = s.tutorialStep;
    final acks = t.meta.raw.obj('tutorial').obj('steps').raw['ack'] as List;
    if (step != null && acks.contains(step)) engine.enqueue(TutorialAck(step));

    if (_shouldRebirth(s)) {
      engine.enqueue(const Rebirth());
      _endWall();
      _farmSince = null;
      _recovering = (at: _online, stage: (s.progress.stage * t.meta.rebirth.number('recoverTargetRatio')).ceil());
      result.rebirths++;
      result.firstRebirth ??= _elapsed;
      return;
    }
    if (s.progress.farming) {
      _farmSince ??= _elapsed;
      if (_elapsed - _farmSince! >= farmRetry) {
        engine.enqueue(const ChallengeBoss());
        _farmSince = null;
      }
    } else {
      _farmSince = null;
    }
  }

  /// 해금 스테이지 이상에서 한 벽이 `meta.sim.rebirthWallSec`를 넘으면 환생.
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

  /// 골드가 되는 만큼 가장 싼 부위부터 산다 (승급 골드는 남기지 않는다 — 단순 정책).
  void _buyCheapest(GameState s) {
    var gold = s.wallet.gold;
    final levels = {...s.ship.parts};
    while (true) {
      final next = cheapestUpgrade(t, levels);
      if (next == null || gold < next.cost) return;
      gold = gold - next.cost;
      levels[next.part] = (levels[next.part] ?? 0) + 1;
      engine.enqueue(UpgradePart(next.part));
      result.upgrades++;
    }
  }

  void _observe(List<GameEvent> events) {
    for (final e in events) {
      switch (e) {
        case Kill(:final gold):
          _killGold.add((_elapsed, gold));
        case WaveCleared():
          final last = _lastWave;
          if (last != null) _waveGaps.add((_elapsed, _elapsed - last));
          _lastWave = _elapsed;
        case BossFailed():
          result.firstBossFail ??= _elapsed;
          _wallSince ??= _online;
        case StageAdvanced(:final stage):
          if (stage >= 10) result.stage10 ??= _elapsed;
          if (stage >= 40) result.stage40 ??= _elapsed;
          _endWall();
          _lastWave = _elapsed;
          final rec = _recovering;
          if (rec != null && stage >= rec.stage) {
            final took = _online - rec.at;
            final worst = result.rebirthRecoverMax;
            if (worst == null || took > worst) result.rebirthRecoverMax = took;
            _recovering = null;
          }
        case CrewPromoted(:final crewId, :final rarity):
          if (crewId == t.growth.bossCards.starterCrew) result.starterPromotion ??= _elapsed;
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
    result.mapPieces = s.wallet.mapPieces;
    result
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

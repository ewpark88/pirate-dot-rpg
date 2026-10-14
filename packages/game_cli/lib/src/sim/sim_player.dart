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
  Duration? firstPromotion;
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

  /// 끝 상태에서 오프라인 8시간 보상으로 살 수 있는 ‘가장 싼 강화’ 횟수.
  int offline8hUpgrades = 0;
}

/// 접속 일정. [online]마다 [offline]만큼 쉰다. [offline]이 0이면 계속 접속.
class SimSchedule {
  const SimSchedule({required this.online, this.offline = Duration.zero});

  final Duration online;
  final Duration offline;
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
  Duration? _farmSince;
  Duration? _wallSince;
  Duration? _lastWave;
  final _waveGaps = <(Duration at, Duration gap)>[];

  /// 일정대로 [total]만큼 (오프라인 포함) 돈다.
  SimResult run(Duration total, SimSchedule schedule) {
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
        _observe(engine.drainEvents());
      }
      if (schedule.offline > Duration.zero && _elapsed < total) _goOffline(schedule.offline);
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
    if (s.wallet.gems >= summonCost(t.meta, 1)) result.firstSummonReady ??= _elapsed;

    engine.enqueue(const MergeAllCards());
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
        case WaveCleared():
          final last = _lastWave;
          if (last != null) _waveGaps.add((_elapsed, _elapsed - last));
          _lastWave = _elapsed;
        case BossFailed():
          result.firstBossFail ??= _elapsed;
          _wallSince ??= _elapsed;
        case StageAdvanced(:final stage):
          if (stage >= 10) result.stage10 ??= _elapsed;
          if (stage >= 40) result.stage40 ??= _elapsed;
          final since = _wallSince;
          if (since != null && _elapsed - since > result.wallMax) result.wallMax = _elapsed - since;
          _wallSince = null;
          _lastWave = _elapsed;
        case CrewPromoted(:final rarity):
          result.firstPromotion ??= _elapsed;
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
    if (since != null && _elapsed - since > result.wallMax) result.wallMax = _elapsed - since;
    double avg(Iterable<Duration> xs) =>
        xs.isEmpty ? 0 : xs.fold(0, (a, d) => a + d.inMilliseconds) / xs.length / Duration.millisecondsPerSecond;
    const early = Duration(minutes: 10);
    result
      ..waveSecFirst10Min = avg([
        for (final (at, gap) in _waveGaps)
          if (at <= early) gap,
      ])
      ..waveSecAll = avg([for (final (_, gap) in _waveGaps) gap])
      ..played = _elapsed
      ..bestStage = s.progress.bestStage
      ..gold = s.wallet.gold
      ..gems = s.wallet.gems
      ..offline8hUpgrades = upgradesAffordable(
        t,
        s.ship.parts,
        goldPerSecEstimate(s, t, offlineFleet(s, t)).times(t.meta.offlineMaxSec),
      );
    return result;
  }
}

/// 지금 레벨에서 가장 싼 강화 (최대 레벨 부위 제외).
({String part, BigNum cost})? cheapestUpgrade(GameTables t, Map<String, int> levels) {
  ({String part, BigNum cost})? best;
  for (final p in t.shipParts.parts) {
    final lv = levels[p.id] ?? 0;
    final max = p.maxLevel;
    if (max != null && lv >= max) continue;
    final cost = partCost(p, lv);
    if (best == null || cost < best.cost) best = (part: p.id, cost: cost);
  }
  return best;
}

/// [gold]로 가장 싼 강화를 몇 번 살 수 있나.
int upgradesAffordable(GameTables t, Map<String, int> levels, BigNum gold) {
  final lv = {...levels};
  var left = gold;
  var n = 0;
  while (true) {
    final next = cheapestUpgrade(t, lv);
    if (next == null || left < next.cost) return n;
    left = left - next.cost;
    lv[next.part] = (lv[next.part] ?? 0) + 1;
    n++;
  }
}

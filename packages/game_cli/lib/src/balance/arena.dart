import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';

/// 측정 장면 (설계서 4.8): (A) 무리전 12마리, (B) 보스전.
enum Scene { swarm, boss }

/// 측정이 성립하지 않을 때 (적이 죽음, 배가 가라앉음, 잘못된 스테이지). 종료 코드 3.
class MeasureError implements Exception {
  MeasureError(this.message);

  final String message;

  @override
  String toString() => 'MeasureError: $message';
}

/// 측정 조건. 기본값은 docs/specs/render-balance-crews.md.
class ArenaConfig {
  const ArenaConfig({
    this.seed = 1,
    this.stage = 2001,
    this.waveCount = 12,
    this.waveKind = 'crab',
    this.hullLevel = 100000,
    this.seconds = 60,
  });

  final int seed;

  /// 적이 죽지 않는 단단한 스테이지. 25의 배수가 아니어야 일반 보스(약점 없음).
  final int stage;
  final int waveCount;
  final String waveKind;

  /// 배가 가라앉지 않게 올리는 선체 레벨 (무적 대신 — 실제 ShipDamaged를 재려고).
  final int hullLevel;
  final double seconds;

  ArenaConfig copyWith({int? seed, int? stage, String? waveKind, int? hullLevel}) => ArenaConfig(
    seed: seed ?? this.seed,
    stage: stage ?? this.stage,
    waveCount: waveCount,
    waveKind: waveKind ?? this.waveKind,
    hullLevel: hullLevel ?? this.hullLevel,
    seconds: seconds,
  );
}

/// 한 판의 결과.
class RunResult {
  RunResult(this.events, this.ticks);

  final List<GameEvent> events;
  final int ticks;
  final Map<String, BigNum> _damage = {};
  BigNum shipDamage = BigNum.zero;
  int kills = 0;
  bool shipSunk = false;

  BigNum damageOf(String crewId) => _damage[crewId] ?? BigNum.zero;

  BigNum get totalDamage => _damage.values.fold(BigNum.zero, (s, d) => s + d);
}

/// 실제 `CoreEngine`(BattleSystem)을 고정 시계·시드로 돌려 선원 피해량을 잰다. 장면은 운영자 명령으로만 만든다.
class Arena {
  Arena(this.t, [this.config = const ArenaConfig()]) {
    if (config.stage % t.regions.midBossEvery == 0) {
      throw MeasureError('S_tank ${config.stage}는 ${t.regions.midBossEvery}의 배수 — 중간·해역 보스(약점 계열)가 나온다');
    }
  }

  final GameTables t;
  final ArenaConfig config;

  static final _start = DateTime.utc(2026);

  Duration get _tick => Duration(milliseconds: t.waves.tickMs);
  int secondsToTicks(double s) => (s * Duration.millisecondsPerSecond / t.waves.tickMs).round();

  /// 보스전 창 = 보스 제한 시간.
  int get bossWindowTicks => secondsToTicks(t.waves.bossTimeLimitSec);

  /// 보스전 피해를 [ArenaConfig.seconds] 기준으로 바꾸는 배율.
  double get bossScale => config.seconds / t.waves.bossTimeLimitSec;

  /// [fleet] 선원들(모두 [level])로 [scene]을 잰다. 보조 선원 없음 = [fleet]에 한 명.
  RunResult run(Scene scene, List<String> fleet, int level) {
    final clock = ManualClock(_start);
    final engine = CoreEngine(
      tables: t,
      clock: clock,
      initial: GameState.newGame(playerId: 'balance', seed: config.seed, now: _start, crews: fleet),
    );
    for (final id in fleet) {
      engine.enqueue(OpSetCrew(id, level: level));
    }
    engine
      ..enqueue(OpSetShip({'hull': config.hullLevel}))
      ..enqueue(OpSetFleet(fleet))
      ..enqueue(OpJumpStage(config.stage));
    _step(engine, clock);
    engine
      ..drainEvents()
      ..enqueue(
        scene == Scene.swarm ? OpSetWave(count: config.waveCount, enemyKind: config.waveKind) : const OpSpawnBoss(),
      );
    final ticks = scene == Scene.swarm ? secondsToTicks(config.seconds) : bossWindowTicks;
    final events = <GameEvent>[];
    for (var i = 0; i < ticks; i++) {
      _step(engine, clock);
      events.addAll(engine.drainEvents());
    }
    final r = RunResult(events, ticks);
    for (final e in events) {
      switch (e) {
        case Damage(:final crewId?, :final amount):
          r._damage[crewId] = (r._damage[crewId] ?? BigNum.zero) + amount;
        case ShipDamaged(:final amount, :final hpRatio):
          r.shipDamage = r.shipDamage + amount;
          if (hpRatio <= 0) r.shipSunk = true;
        case Kill():
          r.kills++;
        default:
          break;
      }
    }
    if (r.kills > 0) throw MeasureError('측정 중 처치 ${r.kills}번 — S_tank(${config.stage})를 올려라 (오버킬이 섞인다)');
    if (r.shipSunk) throw MeasureError('배가 가라앉음 — hullLevel(${config.hullLevel})을 올려라');
    return r;
  }

  void _step(CoreEngine engine, ManualClock clock) {
    engine.tick();
    clock.advance(_tick);
  }
}

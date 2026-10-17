import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/core_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/recording.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 선원 공격 미리보기 하네스(S1 2026-10-17 '넣으면 어떻게 공격하는지 알 수 있게' — 운영자 선원 시험과 같은 장면을 공용으로):
/// 그 선원 혼자 배에 태우고 무리(swarm 마리) ↔ 보스를 phaseSec마다 번갈아 부르며 실제 엔진을 돌린다. 배는 무적.
/// 앱 엔진과 따로 도는 엔진이라 저장·진행·지갑·퀘스트·도감·분석에 닿지 않는다 — 이벤트는 [step]을 부른 쪽만 본다.
/// 같은 표·선원·레벨이면 같은 기록(시드·시계 고정). 설정은 waves.top.crewPreview {stage, swarm, phaseSec, seed}.
class CrewPreview {
  CrewPreview(GameTables tables, {required String crewId, required int level}) : _cfg = config(tables) {
    final start = DateTime.utc(2026);
    final stage = _cfg.integer('stage');
    final state = GameState.newGame(playerId: 'preview', seed: _cfg.integer('seed'), now: start).copyWith(
      progress: Progress(stage: stage, bestStage: stage),
      crews: {crewId: CrewState(level: level)},
      collection: {crewId},
      fleet: [crewId],
      fleetInit: true,
    );
    _clock = _TickClock(start, Duration(milliseconds: tables.waves.tickMs));
    _engine = CoreEngine(tables: tables, clock: _clock, initial: state)
      ..enqueue(const OpSetInvincible(on: true))
      ..enqueue(const OpSetShipStill(on: true)) // 배가 돌아다니면 공격 모양이 안 보인다(순항 끔)
      ..enqueue(OpSetWave(count: _cfg.integer('swarm')));
    _phaseTicks = (_cfg.number('phaseSec') / secondsPerMillisecond / tables.waves.tickMs).round();
  }

  /// 표에 crewPreview가 없으면 미리보기를 끈다(창을 그리지 않음).
  static bool enabled(GameTables t) => t.waves.raw.obj('top').has('crewPreview');

  static JsonReader config(GameTables t) => t.waves.raw.obj('top').obj('crewPreview');

  final JsonReader _cfg;
  late final _TickClock _clock;
  late final CoreEngine _engine;
  late final int _phaseTicks;
  var _ticks = 0;

  /// 한 틱 돌리고 그 틱의 기록. phaseSec마다 무리 ↔ 보스를 번갈아 부른다(보스를 부르면 무리는 사라진다).
  RecordedTick step() {
    _ticks++;
    if (_ticks % _phaseTicks == 0) {
      final boss = (_ticks ~/ _phaseTicks).isOdd;
      _engine.enqueue(boss ? const OpSpawnBoss() : OpSetWave(count: _cfg.integer('swarm')));
    }
    _clock.advance();
    _engine.tick();
    return RecordedTick(_engine.state.battle ?? BattleView.empty, _engine.drainEvents());
  }
}

/// 틱마다 한 칸씩 가는 시계(벽시계와 무관 — 결정론).
class _TickClock implements Clock {
  _TickClock(this._now, this._tick);

  DateTime _now;
  final Duration _tick;

  @override
  DateTime now() => _now;

  void advance() => _now = _now.add(_tick);
}

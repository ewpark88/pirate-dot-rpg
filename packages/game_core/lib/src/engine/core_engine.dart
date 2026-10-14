import 'dart:collection';

import 'package:game_core/src/battle/battle_system.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_core/src/ports/xorshift_rng.dart';
import 'package:game_data/game_data.dart';

/// 기본 시스템 순서: 경제(명령 대부분) → 전투(틱 대부분). 전투는 시뮬 내부 상태를 가지므로 엔진마다 새로 만든다.
List<GameSystem> defaultSystems() => [const EconomySystem(), BattleSystem()];

/// [GameEngine] 구현. 명령 큐·틱·히트스톱·운영자 공통 명령만 직접 다루고,
/// 게임 규칙은 [GameSystem]에 맡긴다.
class CoreEngine implements GameEngine {
  CoreEngine({
    required GameTables tables,
    required Clock clock,
    required GameState initial,
    Rng? rng,
    List<GameSystem>? systems,
  }) : _systems = systems ?? defaultSystems(),
       _state = initial.battle == null ? initial.copyWith(battle: BattleView.empty) : initial {
    _rng = rng ?? XorShiftRng(initial.rngSeed);
    _ctx = SystemContext(tables: tables, clock: clock, rng: _rng, onEvent: _events.add);
    tickLength = Duration(milliseconds: tables.waves.tickMs);
  }

  final List<GameSystem> _systems;
  final Queue<Command> _queue = Queue();
  final List<GameEvent> _events = [];
  late final Rng _rng;
  late final SystemContext _ctx;
  GameState _state;

  /// 처리한 시스템이 없어 버려진 명령 (테스트·운영자 로그용).
  final List<Command> unhandled = [];

  @override
  late final Duration tickLength;

  @override
  GameState get state => _state.copyWith(rngSeed: _rng.state);

  BattleView get _battle => _state.battle!;

  @override
  void enqueue(Command command) => _queue.add(command);

  @override
  void tick() {
    final b = _battle;
    _ctx.tick = b.tick;
    while (_queue.isNotEmpty) {
      _apply(_queue.removeFirst());
    }
    if (_battle.speed == 0) return;
    if (_battle.hitStopTicks > 0) {
      _setBattle(_copyBattle(_battle, hitStopTicks: _battle.hitStopTicks - 1));
      return;
    }
    _step();
  }

  void _step() {
    for (final s in _systems) {
      _state = s.update(_state, _ctx);
    }
    // 이번 틱에 나온 히트스톱 중 가장 긴 것을 건다. 다음 틱부터 멈춘다.
    final stop = _events
        .whereType<HitStop>()
        .where((e) => e.tick == _ctx.tick)
        .fold(0, (m, e) => e.ticks > m ? e.ticks : m);
    _setBattle(_copyBattle(_battle, tick: _battle.tick + 1, hitStopTicks: stop));
  }

  @override
  void advance(int ticks) {
    for (var i = 0; i < ticks; i++) {
      tick();
    }
  }

  @override
  List<GameEvent> drainEvents() {
    final out = List<GameEvent>.of(_events);
    _events.clear();
    return out;
  }

  void _apply(Command c) {
    if (c is OperatorCommand) {
      _state = _state.copyWith(operator: true);
      if (_applyEngineOperator(c)) return;
    }
    if (c is SetSetting) {
      _state = _state.copyWith(settings: _state.settings.withValue(c.key, c.value));
      return;
    }
    for (final s in _systems) {
      final next = s.handle(_state, c, _ctx);
      if (next != null) {
        _state = next;
        return;
      }
    }
    unhandled.add(c);
  }

  /// 엔진이 직접 처리하는 운영자 명령 (배속·1틱·상태 불러오기).
  bool _applyEngineOperator(OperatorCommand c) {
    switch (c) {
      case OpSetSpeed(:final speed):
        _setBattle(_copyBattle(_battle, speed: speed));
      case OpStepTick():
        _step();
      case OpLoadState(:final state):
        _state = state.copyWith(operator: true, battle: state.battle ?? BattleView.empty);
      default:
        return false;
    }
    return true;
  }

  void _setBattle(BattleView b) => _state = _state.copyWith(battle: b);
}

BattleView _copyBattle(BattleView b, {int? tick, int? hitStopTicks, int? speed}) =>
    b.copyWith(tick: tick, hitStopTicks: hitStopTicks, speed: speed);

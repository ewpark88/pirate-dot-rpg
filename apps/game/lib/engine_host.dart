import 'dart:async';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 앱 안에서 엔진을 돌리는 곳 (S1). 20Hz 타이머로 [CoreEngine]을 틱하고,
/// 매 틱 상태를 [onState]로, 전장 스냅샷+이벤트를 [ticks]로 내보낸다.
///
/// - UI: `commandSinkProvider`가 이 객체(→ [send])이고, [onState]가 `gameStateProvider`를 바꾼다 (main.dart).
/// - 렌더: [ticks]를 구독해 라이브 재생한다 (RecordedTick 형식은 fixtures/events와 같다).
/// - 저장: [store]가 있으면 `SaveRequested` 이벤트, [autosaveEvery]마다, [save] 호출(백그라운드 전환) 때 쓴다.
class EngineHost implements CommandSink {
  EngineHost({
    required GameTables tables,
    required GameState initial,
    required this.clock,
    this.store,
    this.autosaveEvery = const Duration(seconds: 10),
  }) : _tables = tables,
       engine = CoreEngine(tables: tables, clock: clock, initial: initial);

  final GameTables _tables;

  /// [resume]이 새로 만들 수 있어 final이 아니다.
  CoreEngine engine;
  final Clock clock;
  final SaveStore? store;

  /// 주기 저장 간격 (docs/lanes/platform.md: 10초).
  final Duration autosaveEvery;
  final StreamController<RecordedTick> _ticks = StreamController.broadcast(sync: true);
  Timer? _timer;
  DateTime? _lastSave;
  Future<void> _saving = Future.value();

  /// 매 틱 새 상태 (UI 갱신).
  void Function(GameState state)? onState;

  /// 매 틱 전장 스냅샷 + 그 틱의 이벤트 (렌더).
  Stream<RecordedTick> get ticks => _ticks.stream;

  GameState get state => engine.state;

  bool get running => _timer != null;

  @override
  void send(Command command) => engine.enqueue(command);

  void start() => _timer ??= Timer.periodic(engine.tickLength, (_) => step());

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 한 주기. 배속(BattleView.speed 1·2·4)만큼 엔진 틱을 돌린다. 테스트는 이것을 직접 부른다.
  void step() {
    final speed = engine.state.battle?.speed ?? 1;
    var saveRequested = false;
    for (var i = 0; i < speed; i++) {
      engine.tick();
      final s = engine.state;
      final events = engine.drainEvents();
      saveRequested |= events.any((e) => e is SaveRequested);
      _ticks.add(RecordedTick(s.battle ?? BattleView.empty, events));
    }
    onState?.call(engine.state);
    final last = _lastSave;
    if (saveRequested || last == null || clock.now().difference(last) >= autosaveEvery) unawaited(save());
  }

  /// 지금 상태를 저장한다 (저장 시각 = 지금). 저장은 한 번에 하나씩 순서대로.
  Future<void> save() {
    final s = store;
    if (s == null) return Future.value();
    final now = clock.now();
    _lastSave = now;
    final text = SaveCodec.encode(engine.state.copyWith(savedAt: now));
    return _saving = _saving.then((_) => s.write(text));
  }

  /// 백그라운드로 갈 때: 멈추고, 지금 시각을 savedAt으로 저장한다.
  Future<void> pause() {
    stop();
    _pausedAt = clock.now();
    return save();
  }

  /// 돌아올 때: 엔진 상태의 savedAt을 멈춘 시각으로 맞춰 다시 만든 뒤 돈다.
  /// 그래야 ClaimOffline이 `now − savedAt`으로 백그라운드에 있던 시간만 센다 (설계서 4.7).
  /// 전장은 새 엔진에서 현재 파를 처음부터 다시 만든다.
  void resume() {
    final at = _pausedAt;
    if (at != null) {
      engine = CoreEngine(
        tables: _tables,
        clock: clock,
        initial: engine.state.copyWith(savedAt: at),
      );
      _pausedAt = null;
    }
    start();
  }

  DateTime? _pausedAt;

  Future<void> dispose() async {
    stop();
    await _saving;
    await _ticks.close();
  }
}

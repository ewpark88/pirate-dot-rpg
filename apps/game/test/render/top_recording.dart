import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';

/// 탑다운(T1 엔진, Settings.battleView 'top') 실제 전투 기록 — 렌더 T2 테스트·시안용. 같은 시드면 같은 기록.
List<RecordedTick> topRecording(
  GameTables t, {
  int ticks = 240,
  int stage = 31,
  int bossAt = -1,
  double fever = 0,
  Map<String, int> levels = const {'octo': 30, 'pang': 28, 'sword': 26, 'turtle': 24},
}) {
  final start = DateTime.utc(2026, 11);
  final state = GameState.newGame(playerId: 'top', seed: 2026, now: start).copyWith(
    progress: Progress(stage: stage, bestStage: stage, rage: 0.6, fever: fever),
    ship: const ShipState(parts: {'cannon': 24, 'hull': 40, 'sail': 10, 'crowsnest': 15, 'cargo': 10}),
    crews: {for (final MapEntry(:key, :value) in levels.entries) key: CrewState(level: value)},
    collection: levels.keys.toSet(),
  );
  final engine = CoreEngine(tables: t, clock: ManualClock(start), initial: state);
  final out = <RecordedTick>[];
  for (var i = 0; i < ticks; i++) {
    if (i == bossAt) engine.enqueue(const OpSpawnBoss());
    engine.tick();
    out.add(RecordedTick(engine.state.battle!, engine.drainEvents()));
  }
  return out;
}

/// 피버를 [at] 틱부터 [ticks] 틱 동안 강제로 켠 기록 (엔진의 피버 게이지·처치 수가 바뀌어도 장면이 안 흔들리게, S1).
/// [at] 틱에 FeverStarted를 넣고, 그 뒤 프레임의 feverTicksLeft를 줄여 간다.
List<RecordedTick> withFever(List<RecordedTick> rec, {int at = 60, int ticks = 200}) => [
  for (var i = 0; i < rec.length; i++)
    if (i < at || i >= at + ticks)
      rec[i]
    else
      RecordedTick(rec[i].frame.copyWith(feverTicksLeft: at + ticks - i), [
        ...rec[i].events,
        if (i == at) FeverStarted(rec[i].frame.tick, untilTick: rec[i].frame.tick + ticks),
      ]),
];

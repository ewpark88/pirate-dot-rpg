import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';

/// 탑다운(T1 엔진, Settings.battleView 'top') 실제 전투 기록 — 렌더 T2 테스트·시안용. 같은 시드면 같은 기록.
List<RecordedTick> topRecording(GameTables t, {int ticks = 240, int stage = 31, int bossAt = -1}) {
  final start = DateTime.utc(2026, 11);
  final state = GameState.newGame(playerId: 'top', seed: 2026, now: start).copyWith(
    progress: Progress(stage: stage, bestStage: stage, rage: 0.6),
    ship: const ShipState(parts: {'cannon': 24, 'hull': 40, 'sail': 10, 'crowsnest': 15, 'cargo': 10}),
    crews: const {
      'octo': CrewState(level: 30),
      'pang': CrewState(level: 28),
      'sword': CrewState(level: 26),
      'turtle': CrewState(level: 24),
    },
    collection: const {'octo', 'pang', 'sword', 'turtle'},
    settings: const Settings(battleView: 'top'),
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

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 환생 뒤 출항 대기 (사용자 피드백 #19, 요청서 docs/contracts/requests/platform-sail-hold.md):
/// 환생하면 Progress.sailHold — 잔잔한 바다(무리·보스·빠른 항해 없음), StartVoyage를 받아야 시작.
void main() {
  final start = DateTime.utc(2026, 11);
  final tables = GameTables.load();

  CoreEngine reborn() {
    final e = CoreEngine(
      tables: tables,
      clock: ManualClock(start),
      initial: GameState.newGame(playerId: 'h', seed: 3, now: start).copyWith(
        progress: const Progress(stage: 60, bestStage: 60),
        crews: const {'octo': CrewState(level: 30)},
      ),
    )..enqueue(const OpRebirthNow());
    return e;
  }

  List<GameEvent> run(CoreEngine e, double seconds) {
    final events = <GameEvent>[];
    for (var i = 0; i < seconds * 1000 / tables.waves.tickMs; i++) {
      e.tick();
      events.addAll(e.drainEvents());
    }
    return events;
  }

  test('환생하면 출항 대기: 20초 동안 무리·보스·빠른 항해가 없다', () {
    final e = reborn();
    final events = run(e, 20);
    expect(e.state.progress.rebirths, 1);
    expect(e.state.progress.sailHold, isTrue);
    expect(events.whereType<FastSailStarted>(), isEmpty);
    expect(events.whereType<BossSpawned>(), isEmpty);
    expect(e.state.battle?.enemies.where((x) => x.eventKind == null) ?? const [], isEmpty);
  });

  test('StartVoyage → 대기 풀림, 빠른 항해 시작 · 대기가 아니면 StartVoyage는 아무것도 안 한다', () {
    final e = reborn();
    run(e, 2);
    e.enqueue(const StartVoyage());
    final events = run(e, 5);
    expect(e.state.progress.sailHold, isFalse);
    expect(events.whereType<FastSailStarted>(), hasLength(1));
    final before = e.state.progress;
    e.enqueue(const StartVoyage());
    run(e, 0.05);
    expect(e.state.progress.sailHold, before.sailHold);
  });

  test('세이브: 대기 중이면 sailHold 키, 아니면 키 없음(옛 세이브 그대로)', () {
    const held = Progress(rebirths: 1, sailHold: true);
    expect(held.toJson()['sailHold'], isTrue);
    expect(Progress.fromJson(held.toJson()).sailHold, isTrue);
    expect(const Progress().toJson().containsKey('sailHold'), isFalse);
    expect(Progress.fromJson(const Progress().toJson()).sailHold, isFalse);
  });
}

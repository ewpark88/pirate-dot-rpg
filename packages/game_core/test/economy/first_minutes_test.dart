import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 설계서 4.12 튜토리얼 1~3단계 (S1 요청: 초반 흐름).
/// apps/game/test/render/first_minutes_test.dart(렌더 레인)의 같은 검증을 코어에서 먼저 확인한다.
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 10, 14);

  CoreEngine fresh(int seed) => CoreEngine(
    tables: t,
    clock: ManualClock(start),
    initial: GameState.newGame(playerId: 'first', seed: seed, now: start, crews: t.meta.startingCrews),
  );

  test('입력 없이 3분: 시작 편성이 스테이지 1·2 보스를 잡고 스테이지 3에 닿는다', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final e = fresh(seed);
      var cleared = 0;
      for (var i = 0; i < 3 * Duration.secondsPerMinute * Duration.millisecondsPerSecond ~/ t.waves.tickMs; i++) {
        e.tick();
        cleared += e.drainEvents().whereType<BossCleared>().length;
      }
      expect(cleared, greaterThanOrEqualTo(2), reason: 'seed $seed');
      expect(e.state.progress.stage, greaterThanOrEqualTo(3), reason: 'seed $seed');
    }
  });
}

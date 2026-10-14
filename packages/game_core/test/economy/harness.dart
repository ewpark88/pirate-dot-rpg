import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';

/// 경제 테스트 공용: 테이블·시계·시드 고정 난수와 이벤트 모음.
class EconomyHarness {
  EconomyHarness({int seed = 7}) : clock = ManualClock(start), rng = XorShiftRng(seed) {
    ctx = SystemContext(tables: tables, clock: clock, rng: rng, onEvent: events.add);
  }

  static final tables = GameTables.load();
  static final start = DateTime.utc(2026, 11);

  final ManualClock clock;
  final XorShiftRng rng;
  final List<GameEvent> events = [];
  late final SystemContext ctx;

  GameState newGame({BigNum gold = BigNum.zero, int gems = 0}) =>
      GameState.newGame(
        playerId: 'test',
        seed: 1,
        now: start,
      ).copyWith(
        wallet: Wallet(gold: gold, gems: gems),
      );

  List<T> of<T extends GameEvent>() => events.whereType<T>().toList();
}

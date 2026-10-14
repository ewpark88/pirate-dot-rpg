import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/engine_host.dart';

void main() {
  final tables = GameTables.load();
  final start = DateTime.utc(2026, 11);

  EngineHost hostOf() => EngineHost(
    tables: tables,
    initial: GameState.newGame(playerId: 't', seed: 1, now: start, crews: tables.meta.startingCrews),
    clock: ManualClock(start),
  );

  test('step 한 번 = 엔진 1틱: 상태를 알리고 RecordedTick을 낸다', () async {
    final host = hostOf();
    final states = <GameState>[];
    final ticks = <RecordedTick>[];
    host.onState = states.add;
    host.ticks.listen(ticks.add);
    host
      ..step()
      ..step();
    expect(states, hasLength(2));
    expect(ticks.map((t) => t.frame.tick), [1, 2]);
    expect(ticks.first.frame.enemies, isNotEmpty); // 첫 틱에 무리 생성
    await host.dispose();
  });

  test('send는 다음 틱에 엔진이 처리한다', () async {
    final host = hostOf()..send(const OpSpawnBoss());
    final ticks = <RecordedTick>[];
    host.ticks.listen(ticks.add);
    host.step();
    expect(ticks.single.events.whereType<BossSpawned>(), hasLength(1));
    await host.dispose();
  });

  test('배속 2면 step 한 번에 2틱', () async {
    final host = hostOf()..send(const OpSetSpeed(2));
    final ticks = <RecordedTick>[];
    host.ticks.listen(ticks.add);
    host
      ..step() // 배속 명령 적용 (이번 주기는 1틱)
      ..step();
    expect(ticks, hasLength(3));
    await host.dispose();
  });
}

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

  test('pause → 시간 경과 → resume: savedAt이 멈춘 시각이라 ClaimOffline은 백그라운드 시간만 센다', () async {
    final clock = ManualClock(start);
    final host = EngineHost(
      tables: tables,
      initial: GameState.newGame(playerId: 't', seed: 1, now: start, crews: tables.meta.startingCrews),
      clock: clock,
    );
    clock.advance(const Duration(minutes: 30)); // 30분 플레이
    host.step();
    await host.pause();
    clock.advance(const Duration(hours: 1)); // 1시간 백그라운드
    host
      ..resume()
      ..stop();
    expect(host.state.savedAt, start.add(const Duration(minutes: 30)));
    await host.dispose();
  });

  test('pause 두 번(onPause → onDetach)이어도 멈춘 시각은 처음 것, 타이머는 꺼진 채', () async {
    final clock = ManualClock(start);
    final host = EngineHost(
      tables: tables,
      initial: GameState.newGame(playerId: 't', seed: 1, now: start, crews: tables.meta.startingCrews),
      clock: clock,
    )..start();
    clock.advance(const Duration(minutes: 10));
    await host.pause();
    clock.advance(const Duration(seconds: 5));
    await host.pause();
    expect(host.running, isFalse);
    host
      ..resume()
      ..stop();
    expect(host.state.savedAt, start.add(const Duration(minutes: 10)));
    await host.dispose();
  });

  test('markPresent(광고 화면): 오프라인 기준 시각을 지금으로 + UI에 바로 알림 → 복귀 보상 없음', () async {
    final clock = ManualClock(start);
    final seen = <GameState>[];
    final host = EngineHost(
      tables: tables,
      initial: GameState.newGame(playerId: 't', seed: 1, now: start, crews: tables.meta.startingCrews),
      clock: clock,
    )..onState = seen.add;
    clock.advance(const Duration(hours: 2)); // 세션이 오래 돎(savedAt은 시작 시각 그대로)
    host.markPresent();
    expect(host.state.savedAt, start.add(const Duration(hours: 2)));
    expect(seen.last.savedAt, start.add(const Duration(hours: 2)));
    clock.advance(const Duration(seconds: 30)); // 광고 30초
    expect(offlinePreview(host.state, tables, clock.now()), isNull);
    await host.dispose();
  });

  test('resume은 다시 만든 상태를 UI에 바로 알린다(다음 틱까지 옛 savedAt을 읽지 않게)', () async {
    final clock = ManualClock(start);
    final seen = <GameState>[];
    final host = EngineHost(
      tables: tables,
      initial: GameState.newGame(playerId: 't', seed: 1, now: start, crews: tables.meta.startingCrews),
      clock: clock,
    )..onState = seen.add;
    clock.advance(const Duration(hours: 1));
    await host.pause();
    clock.advance(const Duration(seconds: 20));
    host
      ..resume()
      ..stop();
    expect(seen.last.savedAt, start.add(const Duration(hours: 1)));
    await host.dispose();
  });

  test('저장이 한 번 던져도 다음 저장은 계속된다', () async {
    final store = _FlakyStore();
    final host = EngineHost(
      tables: tables,
      initial: GameState.newGame(playerId: 't', seed: 1, now: start),
      clock: ManualClock(start),
      store: store,
    );
    await host.save(); // 던짐
    await host.save(); // 이어서 써야 한다
    expect(store.writes, 2);
    await host.dispose();
  });
}

class _FlakyStore implements SaveStore {
  int writes = 0;

  @override
  Future<String?> read() async => null;

  @override
  Future<String?> readBackup() async => null;

  @override
  Future<void> write(String json) async {
    writes += 1;
    if (writes == 1) throw StateError('디스크 오류');
  }
}

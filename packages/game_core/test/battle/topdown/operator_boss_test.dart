import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 운영자 '오늘 새 기능'(설계서 6.10): 보스 골라 소환 · 브레이크 게이지 가득.
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11);
  CoreEngine engine() => CoreEngine(
    tables: t,
    clock: ManualClock(start),
    initial: GameState.newGame(playerId: 'op', seed: 1, now: start).copyWith(
      progress: const Progress(stage: 12, bestStage: 12),
    ),
  );

  test('OpSpawnBoss(bossId): 스테이지 보스 대신 그 보스 · 없으면 스테이지 보스', () {
    final e = engine()
      ..enqueue(const OpSpawnBoss(bossId: 'kraken'))
      ..tick();
    expect(e.drainEvents().whereType<BossSpawned>().single.kind, 'kraken');
    final plain = engine()
      ..enqueue(const OpSpawnBoss())
      ..tick();
    expect(plain.drainEvents().whereType<BossSpawned>().single.kind, t.regions.bossAt(12).id);
  });

  test('OpBossBreak: 보스전 중이면 곧 쓰러진다(BossBroken), 보스가 없거나 표에 브레이크가 없으면 아무 일 없음', () {
    if (!t.skills.raw.has('bossBreak')) {
      final off = engine()
        ..enqueue(const OpSpawnBoss())
        ..tick()
        ..enqueue(const OpBossBreak())
        ..tick()
        ..tick();
      expect(off.drainEvents().whereType<BossBroken>(), isEmpty);
      return;
    }
    final e = engine()
      ..enqueue(const OpSpawnBoss())
      ..tick()
      ..enqueue(const OpBossBreak());
    final events = <GameEvent>[];
    for (var i = 0; i < 3; i++) {
      e.tick();
      events.addAll(e.drainEvents());
    }
    expect(events.whereType<BossBroken>(), hasLength(1));
    final idle = engine()
      ..enqueue(const OpBossBreak())
      ..tick();
    expect(idle.drainEvents().whereType<BossBroken>(), isEmpty);
  });
}

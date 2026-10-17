import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 피버는 스테이지와 상관없이 화면 꽉(S1 실기기 2026-10-17 — 6-2 피버에 화면 적 8마리): 고리가 몇 초 만에 쓸려도
/// fever.swarm.refillBelow 아래로 줄면 고리를 또 부르고, 한 고리는 최소 fever.swarm.min마리.
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11, 2, 3);

  test('스테이지 6 피버 내내 화면 적 중앙값 30마리 이상', () {
    final now = start;
    var s = GameState.newGame(
      playerId: 'f',
      seed: 3,
      now: now,
      crews: t.meta.startingCrews,
    ).copyWith(clearTutorial: true);
    s = s.copyWith(
      progress: s.progress.copyWith(stage: 6, bestStage: 6, fever: 0.999),
      crews: const {'octo': CrewState(level: 30), 'manta': CrewState(level: 30), 'pang': CrewState(level: 30)},
      ship: const ShipState().withLevel('cannon', 20).withLevel('hull', 20),
    );
    final e = CoreEngine(tables: t, clock: ManualClock(now), initial: s)..enqueue(const OpSetInvincible(on: true));
    final counts = <int>[];
    var started = false;
    for (var i = 0; i < 2400; i++) {
      e.tick();
      final ev = e.drainEvents();
      started |= ev.any((x) => x is FeverStarted);
      if (ev.any((x) => x is FeverEnded)) break;
      final v = e.state.battle!;
      if (!started || v.feverTicksLeft <= 0) continue;
      counts.add(v.enemies.where((m) => !m.boss && inCamera(t, m.x, m.y)).length);
    }
    expect(started, isTrue);
    expect(t.meta.raw.obj('fever').obj('swarm').integer('min'), greaterThanOrEqualTo(60));
    final empty = counts.where((n) => n == 0).length;
    expect(
      empty * t.waves.tickMs / 1000,
      lessThanOrEqualTo(0.5),
      reason: '피버 중 화면 0마리 시간(초) — 고리가 다 녹으면 바로 다음 고리(실기기 7-2)',
    );
    counts.sort();
    expect(counts[counts.length ~/ 2], greaterThanOrEqualTo(30), reason: '피버 화면 적 중앙값 (${counts.length}틱)');
    expect(counts[counts.length ~/ 5], greaterThanOrEqualTo(10), reason: '빈 바다 시간이 길지 않게(하위 20%)');
  });
}

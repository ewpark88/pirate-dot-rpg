import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 종 해금(사용자 2026-10-18 '초반에는 1~2종만, 환생·스테이지가 높아질수록 다양하게'): regions.speciesUnlock.
void main() {
  final t = GameTables.load();

  test('해역 안 스테이지로 1 → 2 → 3종…, 환생마다 +1, 해역 목록을 넘지 않음', () {
    expect(t.regions.enemiesAt(1), ['crab']);
    expect(t.regions.enemiesAt(5), hasLength(1));
    expect(t.regions.enemiesAt(6), hasLength(2));
    expect(t.regions.enemiesAt(16), hasLength(3));
    expect(t.regions.enemiesAt(50), t.regions.regionAt(50).enemies);
    expect(t.regions.enemiesAt(1, rebirths: 1), hasLength(2));
    expect(t.regions.enemiesAt(1, rebirths: 9), t.regions.regionAt(1).enemies);
    // 새 해역은 다시 1종부터 — 첫 종은 그 해역의 새 얼굴(앞 해역에 없던 종).
    final storm = t.regions.enemiesAt(51);
    expect(storm, hasLength(1));
    expect(t.regions.regionAt(1).enemies, isNot(contains(storm.single)));
    // 무한 항해(301 = 1의 해역)도 같은 규칙.
    expect(t.regions.enemiesAt(301), ['crab']);
  });

  (Set<String>, Set<String>) run({required int stage, int rebirths = 0}) {
    final start = DateTime.utc(2026, 11);
    var s = GameState.newGame(playerId: 'u', seed: 3, now: start);
    s = s.copyWith(progress: s.progress.copyWith(stage: stage, bestStage: stage, rebirths: rebirths));
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: s)..enqueue(const OpSetInvincible(on: true));
    final seen = <String>{};
    for (var i = 0; i < 900; i++) {
      e
        ..tick()
        ..drainEvents();
      for (final f in e.state.battle?.enemies ?? const <EnemyView>[]) {
        if (!f.boss) seen.add(f.kind);
      }
    }
    return (seen, t.regions.enemiesAt(stage, rebirths: rebirths).toSet());
  }

  test('엔진 무리는 해금된 종만 — 초반 1종, 환생하면 늘어남', () {
    final (early, allowed) = run(stage: 2);
    expect(early, isNotEmpty);
    expect(allowed.containsAll(early), isTrue, reason: '$early ⊄ $allowed');
    final (reborn, allowed2) = run(stage: 2, rebirths: 2);
    expect(allowed2.containsAll(reborn), isTrue);
    expect(reborn.length, greaterThan(early.length));
  });
}

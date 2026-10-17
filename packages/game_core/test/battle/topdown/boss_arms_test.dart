import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 보스 촉수 자리(S5 2026-10-18 — 크라켄 촉수가 원 전체에 놓여 옆 자리가 카메라 밖 → 조준이 안 돼 보호막이 영영 안 꺼졌다).
void main() {
  test('촉수는 모두 카메라 안(배 위쪽 armsArcDeg 호)에 선다', () {
    final t = GameTables.load();
    final start = DateTime.utc(2026, 11, 2, 3);
    final kraken = [for (var s = 1; s <= 300; s++) s].firstWhere((s) => t.regions.bossAt(s).id == 'kraken');
    final e =
        CoreEngine(
            tables: t,
            clock: ManualClock(start),
            initial: GameState.newGame(playerId: 'k', seed: 1, now: start),
          )
          ..enqueue(const OpSetInvincible(on: true))
          ..enqueue(OpJumpStage(kraken))
          ..tick()
          ..enqueue(const OpSpawnBoss())
          ..tick();
    final arms = e.state.battle!.enemies.where((x) => x.kind.endsWith('_tentacle')).toList();
    expect(arms, isNotEmpty);
    for (final a in arms) {
      expect(inCamera(t, a.x, a.y), isTrue, reason: '${a.kind} (${a.x.round()}, ${a.y.round()})');
    }
  });
}

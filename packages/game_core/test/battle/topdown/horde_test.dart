import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/spawner.dart' show hordeCountAt;
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 대군 습격(사용자 2026-10-17 '스테이지를 넘어갈 때마다 많이 몰려들게, 부하도 생각'): 스테이지 첫 파는
/// waves.top.horde 마리가 사방에서 한꺼번에 — 한 파 몫(HP 총량)은 평소 파와 같다.
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11, 2, 3);

  test('마리 수: 스테이지 1에 min, rampStage에 max, 평소 무리 상한 120', () {
    final h = t.waves.raw.obj('top').obj('horde');
    expect(hordeCountAt(t, 1), h.integer('min'));
    expect(hordeCountAt(t, h.integer('rampStage')), h.integer('max'));
    expect(hordeCountAt(t, 9999), h.integer('max'));
    expect(hordeCountAt(t, 50), inInclusiveRange(h.integer('min'), h.integer('max')));
    expect(t.waves.topMobCountAt(9999), 120);
  });

  test('보스를 잡고 다음 스테이지 첫 파 = 대군 습격(HordeIncoming, 사방 4사분면), HP 총량은 평소 한 파와 같다', () {
    final s = GameState.newGame(playerId: 'h', seed: 4, now: start, crews: t.meta.startingCrews).copyWith(
      clearTutorial: true,
      progress: const Progress(stage: 20, bestStage: 20),
      crews: const {'octo': CrewState(level: 60), 'manta': CrewState(level: 60), 'pang': CrewState(level: 60)},
    );
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: s)
      ..enqueue(const OpSetInvincible(on: true))
      ..enqueue(const OpJumpStage(21));
    HordeIncoming? got;
    List<EnemyView>? wave;
    for (var i = 0; i < 400 && got == null; i++) {
      e.tick();
      got = e.drainEvents().whereType<HordeIncoming>().firstOrNull;
      if (got != null) wave = e.state.battle!.enemies.where((x) => !x.boss && !x.vanguard).toList();
    }
    expect(got, isNotNull);
    expect(got!.stage, 21);
    expect(got.count, hordeCountAt(t, 21));
    final top = t.waves.raw.obj('top');
    final q = {
      for (final x in wave!) (x.x > top.number('shipX'), x.y > top.number('shipY')),
    };
    expect(q, hasLength(4), reason: '사방에서');
  });
}

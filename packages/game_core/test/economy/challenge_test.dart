import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 즉석 도전 (docs/specs/platform-fun-fever.md B, 수용 기준 1~3).
void main() {
  final t = EconomyHarness.tables;
  final cfg = t.meta.raw.obj('challenges');
  final tickSec = t.waves.tickMs / 1000;

  GameState start({int stage = 20, double rage = 0}) =>
      GameState.newGame(
        playerId: 'c',
        seed: 11,
        now: EconomyHarness.start,
        crews: t.meta.startingCrews,
      ).copyWith(
        progress: Progress(stage: stage, bestStage: stage, rage: rage),
        clearTutorial: true,
      );

  CoreEngine engine(GameState s) => CoreEngine(tables: t, clock: ManualClock(EconomyHarness.start), initial: s);

  List<GameEvent> run(CoreEngine e, double sec) {
    final out = <GameEvent>[];
    for (var i = 0; i < (sec / tickSec).round(); i++) {
      e.tick();
      out.addAll(e.drainEvents());
    }
    return out;
  }

  test('기준 1: 같은 시드 30분이면 도전 6~10개, 결정론, 끝난 뒤 다음까지 간격 표 범위', () {
    List<(int, String)> starts() => [
      for (final ev in run(engine(start()), 1800))
        if (ev is ChallengeStarted) (ev.tick, ev.id),
    ];
    final a = starts();
    expect(a, starts());
    expect(a.length, inInclusiveRange(6, 10));
  });

  test('기준 2: kills 도전 성공 → ChallengeEnded(success) + 골드, 실패 → 보상 0', () {
    final s0 = start().copyWith(progress: const Progress(stage: 20, bestStage: 20, challengeInSec: 0.05));
    final e = engine(s0);
    final events = run(e, 120);
    final ended = events.whereType<ChallengeEnded>().toList();
    expect(ended, isNotEmpty);
    for (final c in ended) {
      expect(c.success ? c.reward : null, c.success ? isNotNull : isNull);
    }
    expect(e.state.battle!.challenge, isNull);
  });

  test('기준 3: 함성 50%면 ultimate는 나오지 않는다', () {
    final kinds = <String>{};
    for (var seed = 0; seed < 40; seed++) {
      final s = start(rage: t.skills.rageMax * 0.5).copyWith(
        rngSeed: seed,
        progress: Progress(stage: 20, bestStage: 20, rage: t.skills.rageMax * 0.5, challengeInSec: 0.05),
      );
      final e = engine(s)..tick();
      final started = e.drainEvents().whereType<ChallengeStarted>();
      kinds.addAll(started.map((c) => c.id));
    }
    expect(kinds, isNot(contains('ultimate')));
    expect(kinds.length, greaterThanOrEqualTo(2));
  });

  test('noHit: 20초 안 맞으면 성공(무적), 보스전 중엔 시작 안 함', () {
    final ok = cfg.objs('kinds').firstWhere((k) => k.str('id') == 'noHit');
    expect(ok.number('sec'), 20);
    final e = engine(start().copyWith(progress: const Progress(stage: 20, bestStage: 20, challengeInSec: 0.5)))
      ..enqueue(const OpSpawnBoss());
    expect(run(e, 2).whereType<ChallengeStarted>(), isEmpty);
  });
}

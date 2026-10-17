import 'dart:convert';
import 'dart:io';

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 피버 중 보스 처치(S5 2026-10-18 발견 — 보스 처치 때 BattleView를 새로 만들며 피버 남은 시간을 버려 피버가 FeverEnded 없이 끊겼다).
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11, 2, 3);

  test('피버 중 보스를 잡아 스테이지가 올라도 피버 남은 시간 유지 — FeverEnded는 정상 종료 때 한 번만', () {
    var s = GameState.fromJson(
      jsonDecode(File('../../fixtures/states/all_crews_mythic.json').readAsStringSync()) as Map<String, dynamic>,
    ).copyWith(clearTutorial: true, savedAt: start);
    s = s.copyWith(progress: s.progress.copyWith(fever: 0.999));
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: s)
      ..enqueue(const OpSetInvincible(on: true))
      ..enqueue(const OpJumpStage(20));
    final events = <GameEvent>[];
    FeverStarted? started;
    int? leftBefore;
    StageAdvanced? advanced;
    int? leftAfter;
    for (var i = 0; i < 3000 && !events.any((x) => x is FeverEnded); i++) {
      final before = e.state.battle?.feverTicksLeft ?? 0;
      e.tick();
      final evs = e.drainEvents();
      events.addAll(evs);
      if (started == null && evs.whereType<FeverStarted>().isNotEmpty) {
        started = evs.whereType<FeverStarted>().first;
        e.enqueue(const OpSpawnBoss()); // 피버 중 보스 — 신화 함대가 곧 잡는다
      }
      if (started != null && advanced == null && evs.whereType<StageAdvanced>().isNotEmpty) {
        advanced = evs.whereType<StageAdvanced>().first;
        leftBefore = before;
        leftAfter = e.state.battle!.feverTicksLeft;
      }
    }
    expect(started, isNotNull);
    expect(advanced, isNotNull, reason: '피버 중 보스를 잡았다');
    expect(leftBefore, greaterThan(1), reason: '피버가 아직 남아 있을 때 잡았다');
    expect(leftAfter, leftBefore! - 1, reason: '스테이지가 올라도 남은 시간이 한 틱만 준다');
    final ended = events.whereType<FeverEnded>().toList();
    expect(ended, hasLength(1));
    expect(ended.single.tick, started!.untilTick, reason: '정상 종료 시각에');
  });
}

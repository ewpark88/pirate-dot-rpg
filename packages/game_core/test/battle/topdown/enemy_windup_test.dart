import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 쏘기 직전 예고 EnemyWindup(S1 2026-10-18): 원거리 잡몹·보스 기본 포탄·보스 일제 사격이 쏘기 windupSec 전에 예고.
/// 예고만 — 발사·피해·진행은 windupSec을 꺼도 똑같다(sim 불변).
void main() {
  final start = DateTime.utc(2026, 11);

  GameTables tablesWith(double windup) {
    final raw = Map<String, String>.of(rawTables);
    final w = jsonDecode(raw['waves']!) as Map<String, dynamic>;
    (w['top'] as Map<String, dynamic>)['windupSec'] = windup;
    raw['waves'] = jsonEncode(w);
    return GameTables.load(raw);
  }

  /// 원거리 잡몹이 있는 앞 해역 + 보스: [ticks]틱 돌린 (이벤트 전부, 끝 상태 JSON).
  /// 무적은 끈다 — 무적이면 보스 기본 포탄(BossFired)이 아예 나오지 않는다(combat moveFoes).
  (List<GameEvent>, String) run(GameTables t, int ticks) {
    final e = CoreEngine(
      tables: t,
      clock: ManualClock(start),
      initial: GameState.newGame(playerId: 'w', seed: 7, now: start).copyWith(
        progress: const Progress(stage: 8, bestStage: 8, rebirths: 3), // 종 해금: 원거리 잡몹(갈매기)까지 열기
      ),
    );
    final events = <GameEvent>[];
    for (var i = 0; i < ticks; i++) {
      if (i == 200) e.enqueue(const OpSpawnBoss());
      e.tick();
      events.addAll(e.drainEvents());
    }
    return (events, jsonEncode(e.state.toJson()));
  }

  test('예고는 같은 적의 발사 atTicks 틱 전에 온다(원거리 잡몹·보스)', () {
    final (events, _) = run(tablesWith(0.4), 600);
    final windups = events.whereType<EnemyWindup>().toList();
    expect(windups, isNotEmpty);
    expect(windups.map((w) => w.kind).toSet(), contains('ranged'));
    final fired = {for (final f in events.whereType<EnemyFired>()) (f.enemyId, f.tick)};
    final bossFired = {for (final f in events.whereType<BossFired>()) f.tick};
    var matched = 0;
    for (final w in windups.where((w) => w.kind == 'ranged')) {
      // 그 사이 적이 죽거나 기절하면 쏘지 않을 수 있다 — 쏜 것은 반드시 예고한 바로 그 틱.
      if (fired.contains((w.enemyId, w.tick + w.atTicks))) matched++;
    }
    expect(matched, greaterThan(0), reason: '예고 뒤 정확히 atTicks에 쏜 원거리 잡몹');
    // 보스는 정지 지점을 도는 동안 접촉 타이머가 틱마다 고르게 줄지 않는다(이동·패턴 쉼) — 예고 뒤 발사가 몇 틱 늦을 수 있다.
    // 규칙: 예고보다 일찍 쏘지 않고, 대부분 예고 길이(atTicks) 안에 늦게라도 쏜다(큰 보스는 더 멀리 서서 더 늦을 수 있다 — bossScale).
    // 렌더는 EnemyFired·BossFired에서 빛을 끝내므로 늦어도 어긋나 보이지 않는다.
    final shots = bossFired.toList()..sort();
    var near = 0;
    final boss = windups.where((w) => w.kind == 'boss').toList();
    for (final w in boss) {
      final next = shots.where((t) => t > w.tick).firstOrNull;
      if (next == null) continue;
      expect(next, greaterThanOrEqualTo(w.tick + w.atTicks - 1), reason: '보스 예고 ${w.tick}+${w.atTicks} 뒤 발사 $next');
      if (next - w.tick - w.atTicks <= w.atTicks) near++;
    }
    expect(boss, isNotEmpty);
    expect(
      near * 2,
      greaterThanOrEqualTo(boss.length),
      reason: '보스 예고 ${[for (final w in boss) '${w.tick}+${w.atTicks}']} 발사 $shots',
    );
  });

  test('예고를 꺼도 상태는 같다 — 발사·피해·진행 불변(sim 불변)', () {
    final (onEvents, onState) = run(tablesWith(0.4), 600);
    final (offEvents, offState) = run(tablesWith(0), 600);
    expect(offEvents.whereType<EnemyWindup>(), isEmpty);
    expect(onState, offState);
    String plain(List<GameEvent> es) => [
      for (final e in es)
        if (e is! EnemyWindup) jsonEncode(e.toJson()),
    ].join('\n');
    expect(plain(onEvents), plain(offEvents));
  });

  test('저장 형식: EnemyWindup JSON 왕복', () {
    const e = EnemyWindup(9, enemyId: 3, atTicks: 8, kind: 'boss');
    final back = GameEvent.fromJson(e.toJson());
    expect(back, isA<EnemyWindup>().having((x) => x.atTicks, 'atTicks', 8).having((x) => x.kind, 'kind', 'boss'));
  });
}

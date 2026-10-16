import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 사용자 실기기(2026-10-17): '환생 뒤 빠른 항해로 83까지 갔는데 골드·배 레벨이 없어 83-1에서 계속 침몰'.
/// 엔진 경로: 환생 상태 → 빠른 항해(건너뛰기) → 보급(S2 fastSailSupplyLevels) → 도착 스테이지 무리 60초 동안 침몰 없음.
void main() {
  final start = DateTime.utc(2026, 11);

  GameTables tables({bool supply = true}) {
    final raw = Map<String, String>.of(rawTables);
    if (!supply) {
      final waves = jsonDecode(raw['waves']!) as Map<String, dynamic>;
      (waves['rebirthSkip'] as Map<String, dynamic>).remove('supply');
      raw['waves'] = jsonEncode(waves);
    }
    return GameTables.load(raw);
  }

  ({CoreEngine e, List<GameEvent> events, int sunk}) voyage(GameTables t) {
    final reborn = GameState.newGame(playerId: 'u', seed: 3, now: start, crews: t.meta.startingCrews).copyWith(
      progress: const Progress(bestStage: 185, rebirths: 1), // 0.45 × 185 → 83까지 빠른 항해
      crews: {for (final id in t.meta.startingCrews) id: const CrewState(level: 30)},
      clearTutorial: true,
    );
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: reborn)..advance(5);
    final events = <GameEvent>[...e.drainEvents()];
    e
      ..enqueue(const SkipFastSail())
      ..tick();
    events.addAll(e.drainEvents());
    var sunk = 0;
    for (var i = 0; i < 60 * 1000 ~/ t.waves.tickMs; i++) {
      e.tick();
      for (final ev in e.drainEvents()) {
        events.add(ev);
        if (ev is ShipDamaged && ev.hpRatio <= 0) sunk += 1;
      }
    }
    return (e: e, events: events, sunk: sunk);
  }

  test('보급되면 도착 스테이지 무리 60초 동안 침몰 0, ShipResupplied(before → after)', () {
    final r = voyage(tables());
    final ended = r.events.whereType<FastSailEnded>().single;
    expect(ended.to, greaterThanOrEqualTo(80));
    final sup = r.events.whereType<ShipResupplied>().single;
    expect(sup.stage, ended.to + 1);
    expect(sup.after['cannon'], greaterThan(sup.before['cannon']!));
    expect(sup.after['hull'], greaterThan(sup.before['hull']!));
    expect(r.e.state.ship.parts, sup.after);
    expect(r.sunk, 0, reason: '83-1에서 계속 침몰하던 문제');
  });

  test('대조: 보급 표가 없으면 같은 길에서 침몰한다(이 테스트가 문제를 잡는다)', () {
    final r = voyage(tables(supply: false));
    expect(r.events.whereType<ShipResupplied>(), isEmpty);
    expect(r.sunk, greaterThan(0));
  });
}

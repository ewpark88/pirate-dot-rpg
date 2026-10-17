import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 타격 넉백(#82 사용자 '공격 임팩트가 약하다' — waves.top.knockback).
void main() {
  final t = GameTables.load();
  final k = t.waves.raw.obj('top').obj('knockback');
  final dt = t.waves.tickMs / 1000;
  final start = DateTime.utc(2026, 11, 2, 3);

  test('살아남은 적은 배 바깥쪽으로 dist 이하만큼, 한 적은 everySec에 한 번 — BattleView 위치에 반영', () {
    final s = GameState.fromJson(
      jsonDecode(File('../../fixtures/states/stage37_midgame.json').readAsStringSync()) as Map<String, dynamic>,
    ).copyWith(clearTutorial: true, savedAt: start);
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: s)..enqueue(const OpSetInvincible(on: true));
    final last = <int, int>{};
    var n = 0;
    for (var i = 0; i < 1200; i++) {
      e.tick();
      final v = e.state.battle!;
      final sx = v.shipX ?? 0;
      final sy = v.shipY ?? 0;
      for (final ev in e.drainEvents().whereType<Knockback>()) {
        n++;
        expect(math.sqrt(ev.dx * ev.dx + ev.dy * ev.dy), lessThanOrEqualTo(k.number('dist') + 1e-9));
        final foe = v.enemies.where((x) => x.id == ev.enemyId).firstOrNull;
        if (foe != null) {
          expect((foe.x - sx) * ev.dx + (foe.y - sy) * ev.dy, greaterThanOrEqualTo(0), reason: '배 쪽으로 밀지 않는다');
        }
        final prev = last[ev.enemyId];
        if (prev != null) expect(ev.tick - prev, greaterThanOrEqualTo((k.number('everySec') / dt).round()));
        last[ev.enemyId] = ev.tick;
      }
    }
    expect(n, greaterThan(20), reason: '중반 함대는 한 방에 안 죽는 적이 있어 밀린다');
  });

  test('표 키가 없으면 밀지 않는다 · 이벤트 JSON 왕복', () {
    final raw = Map<String, String>.of(rawTables);
    final w = jsonDecode(raw['waves']!) as Map<String, dynamic>;
    (w['top'] as Map<String, dynamic>).remove('knockback');
    raw['waves'] = jsonEncode(w);
    final s = GameState.fromJson(
      jsonDecode(File('../../fixtures/states/stage37_midgame.json').readAsStringSync()) as Map<String, dynamic>,
    ).copyWith(clearTutorial: true, savedAt: start);
    final e = CoreEngine(tables: GameTables.load(raw), clock: ManualClock(start), initial: s);
    var n = 0;
    for (var i = 0; i < 400; i++) {
      e.tick();
      n += e.drainEvents().whereType<Knockback>().length;
    }
    expect(n, 0);
    const ev = Knockback(3, enemyId: 7, dx: 1.5, dy: -2);
    expect(GameEvent.fromJson(ev.toJson()).toJson(), ev.toJson());
  });
}

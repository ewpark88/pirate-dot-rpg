import 'dart:convert';
import 'dart:io';

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 장면 모드 출현 자리(S1 실기기 2026-10-17 '탑에서 배 위에 적이 뭉쳐 배가 안 보인다').
void main() {
  final t = GameTables.load();

  CoreEngine mythic(DateTime start) {
    final s = GameState.fromJson(
      jsonDecode(File('../../fixtures/states/all_crews_mythic.json').readAsStringSync()) as Map<String, dynamic>,
    ).copyWith(clearTutorial: true, savedAt: start);
    return CoreEngine(
      tables: t,
      clock: ManualClock(start),
      initial: s.copyWith(progress: s.progress.copyWith(rebirths: 1)),
    )..tick();
  }

  test('탑 무리는 카메라 테두리 밖에서 생긴다(배 쪽 0.55배로 당겨 위·아래가 화면 안에서 생기던 것)', () {
    final e = mythic(DateTime.utc(2026, 11, 2, 3))..enqueue(const StartTower());
    var seen = <int>{};
    var spawned = 0;
    for (var i = 0; i < 400; i++) {
      e
        ..tick()
        ..drainEvents();
      final v = e.state.battle!;
      final firstTick = v.enemies.where((x) => !seen.contains(x.id) && !x.boss && !x.emerging).toList();
      // 처치 때 갈라지는 새끼(분열)는 그 자리에서 생기니 무리가 새로 들어온 틱(5마리 이상)만 본다.
      if (firstTick.length >= 5) {
        spawned += firstTick.length;
        for (final x in firstTick) {
          expect(inCamera(t, x.x, x.y), isFalse, reason: '${x.kind} (${x.x.round()}, ${x.y.round()})');
        }
      }
      seen = {for (final x in v.enemies) x.id};
    }
    expect(spawned, greaterThan(0));
  });

  test('러시 크라켄: 앞 보스전 비켜서기로 배가 옆(x≈86)에 가 있어도 촉수는 카메라 안 → 보호막이 꺼져 잡힌다', () {
    // 재현 조건: 러시 보스 HP를 DPS 2배 기준(dpsHpRatio 1.6)으로 — 앞 보스전이 길어 배가 왼쪽으로 비켜선 채 크라켄이 나온다.
    final raw = Map<String, String>.of(rawTables);
    final m = jsonDecode(raw['meta']!) as Map<String, dynamic>;
    (m['rush'] as Map<String, dynamic>)['dpsHpRatio'] = 1.6;
    raw['meta'] = jsonEncode(m);
    final start = DateTime.utc(2026, 11, 9, 3);
    final s = GameState.fromJson(
      jsonDecode(File('../../fixtures/states/all_crews_mythic.json').readAsStringSync()) as Map<String, dynamic>,
    ).copyWith(clearTutorial: true, savedAt: start);
    final e =
        CoreEngine(
            tables: GameTables.load(raw),
            clock: ManualClock(start),
            initial: s.copyWith(progress: s.progress.copyWith(rebirths: 1)),
          )
          ..tick() // 도전 횟수 채움
          ..enqueue(const StartRush());
    final downs = <String>[];
    for (var i = 0; i < 3000 && !downs.contains('kraken'); i++) {
      e.tick();
      downs.addAll(e.drainEvents().whereType<RushBossDown>().map((d) => d.bossId));
    }
    expect(downs, contains('kraken'));
  });
}

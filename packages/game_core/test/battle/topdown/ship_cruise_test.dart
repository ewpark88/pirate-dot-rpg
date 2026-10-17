import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 배 순항(waves.top.cruise — 사용자 '내 배가 좀 더 역동적으로, 느리게 움직여서 재미가 없네', S1 2026-10-17).
void main() {
  final t = GameTables.load();
  final top = t.waves.raw.obj('top');
  final c = top.obj('cruise');
  final dt = t.waves.tickMs / 1000;
  final start = DateTime.utc(2026, 11, 2, 3);

  /// 신화 함대 [sec]초: 틱마다 배 자리·머리·보스전·피버.
  List<({double x, double y, double h, bool boss, bool fever})> sail(double sec) {
    final s = GameState.fromJson(
      jsonDecode(File('../../fixtures/states/all_crews_mythic.json').readAsStringSync()) as Map<String, dynamic>,
    ).copyWith(clearTutorial: true, savedAt: start);
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: s);
    return [
      for (var i = 0; i < (sec / dt).round(); i++)
        () {
          e
            ..tick()
            ..drainEvents();
          final v = e.state.battle!;
          return (
            x: (v.shipX ?? top.number('shipX')) - top.number('shipX'),
            y: (v.shipY ?? top.number('shipY')) - top.number('shipY'),
            h: v.shipHeading,
            boss: v.bossActive,
            fever: v.feverTicksLeft > 0,
          );
        }(),
    ];
  }

  final path = sail(180); // 보스 4번·피버 2번이 낀다
  final dash = c.number('speed') * c.number('dashSpeedMul') * c.number('feverSpeedMul');

  test('feverOnly: 피버 중에만 돌아다니고(가로 40 이상), 평소엔 제자리 0 — 피버가 끝나면 몇 초 안에 감속하며 0으로', () {
    expect(c.raw['feverOnly'], isTrue);
    final fever = path.where((p) => p.fever && !p.boss).toList();
    expect(fever, isNotEmpty);
    final xs = fever.map((p) => p.x);
    expect(xs.reduce(math.max) - xs.reduce(math.min), greaterThan(40));
    final r = c.obj('rect');
    for (final p in fever) {
      expect(p.x.abs(), lessThanOrEqualTo(r.number('x') + 1e-6));
      expect(p.y, inInclusiveRange(-r.number('up') - 1e-6, r.number('down') + 1e-6));
    }
    // 평소(피버·보스 아님): 피버·보스전이 끝난 뒤 복귀 몇 초를 빼면 정확히 제자리.
    final settle = (4 / dt).round(); // 복귀 여유 4초
    var sinceFever = settle;
    var resting = 0;
    for (final p in path) {
      sinceFever = p.fever || p.boss ? 0 : sinceFever + 1; // 보스전 뒤 복귀는 결투 비켜서기(예전 동작)
      if (p.boss || p.fever || sinceFever < settle) continue;
      resting++;
      expect((p.x, p.y), (0, 0), reason: '평소는 제자리');
    }
    expect(resting, greaterThan(0));
    var after = 0;
    for (var i = 1; i < path.length; i++) {
      if (path[i - 1].fever && !path[i].fever && !path[i].boss) {
        // 피버 끝: settle 안에 (보스가 끼지 않으면) 0에 닿는다
        var j = i;
        while (j < path.length && j < i + settle && !path[j].boss && (path[j].x != 0 || path[j].y != 0)) {
          j++;
        }
        if (j < path.length && !path[j].boss) {
          expect(path[j].x, 0, reason: '피버 끝 $i → $j');
          after++;
        }
      }
    }
    expect(after, greaterThan(0), reason: '피버 끝 복귀를 한 번은 봤다');
  });

  test('평소 파밍(피버 전 첫 무리): 배는 정확히 0, 머리 0 — 순항 전과 같은 화면', () {
    final calm = path.takeWhile((p) => !p.fever && !p.boss).toList();
    expect(calm.length, greaterThan(20));
    expect(calm.every((p) => p.x == 0 && p.y == 0 && p.h == 0), isTrue);
  });

  test('속력 상한(돌진 × 피버까지)·순간이동 없음(보스 처치 → 다음 스테이지에도 자리 이어 받음)', () {
    var fastest = 0.0;
    for (var i = 1; i < path.length; i++) {
      final v = math.sqrt(math.pow(path[i].x - path[i - 1].x, 2) + math.pow(path[i].y - path[i - 1].y, 2)) / dt;
      fastest = math.max(fastest, v);
    }
    expect(fastest, lessThanOrEqualTo(dash + 1));
    expect(fastest, greaterThan(c.number('speed') * 1.2), reason: '돌진이 한 번은 있다');
  });

  test('큰 호: 움직이는 동안 진행 방향은 초당 turnDegPerSec까지만 꺾이고, 머리는 ±maxTiltDeg', () {
    final turn = c.number('turnDegPerSec') * math.pi / 180;
    final r = c.obj('rect');
    // 벽(rect)에 닿아 멈췄다 떠나는 틱은 뺀다(벽 앞에선 속력만 줄여 멈춘다).
    bool wall(({double x, double y, double h, bool boss, bool fever}) p) =>
        p.x.abs() >= r.number('x') - 2 || p.y <= -r.number('up') + 2 || p.y >= r.number('down') - 2;
    for (var i = 2; i < path.length; i++) {
      final a = path[i - 2];
      final b = path[i - 1];
      final d = path[i];
      if (a.boss || b.boss || d.boss || wall(a) || wall(b) || wall(d)) continue;
      final v1 = (x: b.x - a.x, y: b.y - a.y);
      final v2 = (x: d.x - b.x, y: d.y - b.y);
      final s1 = math.sqrt(v1.x * v1.x + v1.y * v1.y) / dt;
      final s2 = math.sqrt(v2.x * v2.x + v2.y * v2.y) / dt;
      if (s1 < 10 || s2 < 10) continue; // 거의 멈춤
      var da = math.atan2(v2.y, v2.x) - math.atan2(v1.y, v1.x);
      da = math.atan2(math.sin(da), math.cos(da));
      expect(da.abs(), lessThanOrEqualTo(turn * dt + 1e-3), reason: 'tick $i');
    }
    final tilt = c.number('maxTiltDeg') * math.pi / 180;
    expect(path.where((p) => !p.boss).every((p) => p.h.abs() <= tilt + 1e-6), isTrue);
  });
}

import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 보스전 비켜서기 (사용자 피드백 #10, top_duel.dart): 보스가 배 둘레를 한 바퀴 도는 동안 보스·배가 카메라 안에 있다.
void main() {
  final start = DateTime.utc(2026, 11);

  GameTables tables({Map<String, Object>? duel}) {
    final raw = Map<String, String>.of(rawTables);
    final waves = jsonDecode(raw['waves']!) as Map<String, dynamic>;
    final top = waves['top'] as Map<String, dynamic>;
    duel == null ? top.remove('bossDuel') : top['bossDuel'] = duel;
    raw['waves'] = jsonEncode(waves);
    return GameTables.load(raw);
  }

  /// 무적으로 보스를 띄우고 [seconds]초 동안의 화면 값.
  List<BattleView> fight(GameTables t, {double seconds = 30}) {
    final e =
        CoreEngine(
            tables: t,
            clock: ManualClock(start),
            initial: GameState.newGame(playerId: 'd', seed: 1, now: start).copyWith(
              progress: const Progress(stage: 8, bestStage: 8),
            ),
          )
          ..enqueue(const OpSetInvincible(on: true))
          ..enqueue(const OpSpawnBoss());
    final views = <BattleView>[];
    for (var i = 0; i < seconds * 1000 / t.waves.tickMs; i++) {
      e
        ..tick()
        ..drainEvents();
      final v = e.state.battle;
      if (v != null && v.bossActive) views.add(v);
    }
    return views;
  }

  /// 카메라(바다 가운데 고정) 밖으로 보스 몸이 얼마나 나갔나(최대, 0이면 늘 안).
  double outside(GameTables t, List<BattleView> views) {
    final top = t.waves.top;
    final halfW = t.waves.raw.obj('top').number('viewWidth') / 2;
    var worst = 0.0;
    for (final v in views.skip(80)) {
      for (final b in v.enemies.where((e) => e.boss)) {
        worst = [worst, (b.x - top.shipX).abs() + top.bossRadius - halfW].reduce((a, c) => a > c ? a : c);
      }
    }
    return worst;
  }

  test('표 키가 없으면 지금 그대로: 배는 가운데, 보스는 옆·대각선에서 화면 밖으로 나간다(신고된 문제)', () {
    final t = tables();
    final views = fight(t);
    expect(views.every((v) => (v.shipX ?? t.waves.top.shipX) == t.waves.top.shipX), isTrue);
    expect(outside(t, views), greaterThan(0));
  });

  test('bossDuel: 한 바퀴 동안 보스 몸이 화면 안, 배도 화면 안, 배는 speed 이하로 움직인다', () {
    final t = tables(duel: {'shift': 0.5, 'speed': 40});
    final views = fight(t);
    expect(outside(t, views), lessThanOrEqualTo(0));
    final top = t.waves.top;
    final halfW = t.waves.raw.obj('top').number('viewWidth') / 2;
    final step = 40 * t.waves.tickMs / 1000 + 1e-9;
    for (var i = 1; i < views.length; i++) {
      final a = views[i - 1];
      final b = views[i];
      final dx = (b.shipX ?? top.shipX) - (a.shipX ?? top.shipX);
      final dy = (b.shipY ?? top.shipY) - (a.shipY ?? top.shipY);
      expect(dx * dx + dy * dy, lessThanOrEqualTo(step * step), reason: '틱 $i');
      expect(((b.shipX ?? top.shipX) - top.shipX).abs() + top.shipRadius, lessThan(halfW));
    }
    expect(views.any((v) => v.shipX != null && v.shipX != top.shipX), isTrue, reason: '배가 비켜 섰다');
  });
}

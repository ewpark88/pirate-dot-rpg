import 'dart:convert';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

import 'still_ship.dart';

/// 보스전 비켜서기 (사용자 피드백 #10, top_duel.dart): 보스가 배 둘레를 한 바퀴 도는 동안 보스·배가 카메라 안에 있다.
void main() {
  final start = DateTime.utc(2026, 11);

  GameTables tables({Map<String, Object>? duel}) {
    final raw = stillShipRaw();
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

  test('v2(보스와 마주 보며 가운데서): 둘의 가운데 = 바다 가운데보다 rise 위, 배 머리는 보스 쪽, 회전 상한, 끝나면 제자리·위로', () {
    final t = GameTables.load(stillShipRaw());
    final cfg = t.waves.raw.obj('top').obj('bossDuel');
    expect(cfg.number('rise'), greaterThan(0), reason: '표가 v2');
    final rise = cfg.number('rise') * t.waves.raw.obj('top').number('viewHeight');
    final turn = cfg.number('turnDegPerSec') * math.pi / 180;
    final top = t.waves.top;
    final views = fight(t, seconds: 8);
    final settled = views.skip(80).toList(); // 1.5초 올라가기·돌기 뒤
    for (final v in settled) {
      final b = v.enemies.firstWhere((e) => e.boss);
      final sx = v.shipX ?? top.shipX;
      final sy = v.shipY ?? top.shipY;
      // 가로: 둘의 가운데가 화면 가운데(카메라 반폭이 좁다), 세로: 배가 결투 중심(rise 위) 근처 — 가운데서 전투.
      expect((sx + b.x) / 2, closeTo(top.shipX, 12), reason: '가운데 x');
      expect(sy, closeTo(top.shipY - rise, top.bossStandoff * cfg.number('shiftY') + 12), reason: '배가 가운데 높이');
      final face = math.atan2(b.x - sx, -(b.y - sy));
      var d = face - v.shipHeading;
      d = math.atan2(math.sin(d), math.cos(d));
      expect(d.abs(), lessThan(0.35), reason: '머리가 보스 쪽');
    }
    final dt = t.waves.tickMs / 1000;
    for (var i = 1; i < views.length; i++) {
      var d = views[i].shipHeading - views[i - 1].shipHeading;
      d = math.atan2(math.sin(d), math.cos(d));
      expect(d.abs(), lessThanOrEqualTo(turn * dt + 1e-9), reason: '틱 $i 회전 상한');
    }
  });

  test('v2: 보스전이 끝나면 같은 빠르기로 제자리·머리 위(0)로 돌아온다', () {
    final t = GameTables.load(stillShipRaw());
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
    for (var i = 0; i < 100; i++) {
      e
        ..tick()
        ..drainEvents();
    }
    expect(e.state.battle!.shipY, isNot(t.waves.top.shipY), reason: '결투 중엔 올라가 있다');
    e.enqueue(const OpSetWave(count: 1)); // 보스를 치우고 무리 한 파
    for (var i = 0; i < 160; i++) {
      e
        ..tick()
        ..drainEvents();
    }
    final v = e.state.battle!;
    expect(v.shipY ?? t.waves.top.shipY, closeTo(t.waves.top.shipY, 1e-6));
    expect(v.shipHeading.abs(), lessThan(1e-6));
  });

  test('회귀(main 2df68598): 보스가 쓰러져(기절) 원 위로 다시 서지 않는 동안에도 배가 standoff 안으로 파고들지 않는다', () {
    final t = GameTables.load(stillShipRaw());
    final top = t.waves.top;
    final e =
        CoreEngine(
            tables: t,
            clock: ManualClock(start),
            initial: GameState.newGame(playerId: 'k', seed: 2, now: start).copyWith(
              progress: const Progress(stage: 7, bestStage: 7), // enemy_ship(7칸 회전 — 보스 +18)
            ),
          )
          ..enqueue(const OpSetInvincible(on: true))
          ..enqueue(const OpSpawnBoss());
    var broke = false;
    for (var i = 0; i < 200; i++) {
      if (i == 30) e.enqueue(const OpBossBreak());
      e.tick();
      broke |= e.drainEvents().any((x) => x is BossBroken);
      final v = e.state.battle!;
      if (!v.bossActive) continue;
      final b = v.enemies.where((x) => x.boss).firstOrNull;
      if (b == null) continue;
      final d = math.sqrt(math.pow(b.x - (v.shipX ?? top.shipX), 2) + math.pow(b.y - (v.shipY ?? top.shipY), 2));
      expect(d, greaterThanOrEqualTo(top.bossStandoff - 1e-6), reason: '틱 $i');
    }
    if (t.skills.raw.has('bossBreak')) expect(broke, isTrue, reason: '쓰러진 구간을 지나갔다');
  });
}

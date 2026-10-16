import 'dart:async';

import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/render/demo/sample_battle.g.dart';
import 'package:pirate_dot/render/demo/stress_recording.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/perf/perf_monitor.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';

void main() {
  group('수용 기준 1: PerfMonitor', () {
    test('p50·p95·최대·fps', () {
      final m = PerfMonitor();
      // 1..120ms: p50 = 60, p95 = 114 (nearest-rank), 최대 120, 평균 60.5ms → fps 1000/60.5.
      for (var i = 1; i <= 120; i++) {
        m.add(i.toDouble());
      }
      expect(m.p50, 60);
      expect(m.p95, 114);
      expect(m.maxMs, 120);
      expect(m.fps, closeTo(1000 / 60.5, 1e-9));
    });

    test('121번째부터 가장 오래된 값을 밀어낸다', () {
      final m = PerfMonitor();
      for (var i = 0; i < 120; i++) {
        m.add(100);
      }
      for (var i = 0; i < 120; i++) {
        m.add(10);
      }
      expect(m.maxMs, 10);
      expect(m.count, 120);
    });
  });

  group('수용 기준 2: 부하 장면 기록', () {
    final a = stressRecording();

    test('결정론적', () {
      expect(encodeRecording(stressRecording()), encodeRecording(a));
    });

    test('모든 틱이 탑다운, 배 둘레 화면 안(배 ±135·±200)에 적 80 이상, 매 틱 발사', () {
      for (final t in a) {
        expect(t.frame.mode, 'top');
        final near = t.frame.enemies.where((e) => (e.x - 135).abs() <= 135 && (e.y - 240).abs() <= 200);
        expect(near.length, greaterThanOrEqualTo(80));
        expect(t.events.whereType<AttackFired>(), isNotEmpty);
      }
    });
  });

  test('수용 기준 3: 부하 장면 60초 — 상한 유지, 워밍업 뒤 풀 불변', () {
    final s = BattleScene(tables, stressRecording());
    final loopFrames = (stressRecording().length * tickMs / kFrameMs).ceil();
    for (var i = 0; i < loopFrames; i++) {
      s.update(kFrameMs);
    }
    final created = s.stats.pooledObjects;
    for (var i = 0; i < 60 * 60; i++) {
      s.update(kFrameMs);
      expect(s.effects.active.length, lessThanOrEqualTo(tables.juice.maxEffects));
      expect(s.numbers.active.length, lessThanOrEqualTo(tables.juice.maxDamageNumbers));
    }
    expect(s.stats.pooledObjects, created);
  });

  group('수용 기준 4: 절전', () {
    test('60Hz로 1초면 장면 갱신 30회 이하', () {
      final g = BattleGame(
        recording: decodeRecording(sampleBattleJsonl),
        settings: const JuiceSettings(powerSave: true),
      );
      for (var i = 0; i < 60; i++) {
        g.update(1 / 60);
      }
      expect(g.sceneUpdates, lessThanOrEqualTo(30));
      expect(g.sceneUpdates, greaterThanOrEqualTo(29));
    });
  });

  test('수용 기준 6: 부하 장면 → 라이브 복귀', () async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    final g = BattleGame(feed: feed.stream, loadSprites: false)
      ..onGameResize(Vector2(kLogicalWidth * 2, kLogicalHeight * 2));
    await g.onLoad();
    expect(g.mode, BattleMode.live);
    g.loadStress();
    expect(g.mode, BattleMode.stress);
    marching(3).forEach(feed.add);
    expect(g.scene.player.live, isFalse);
    g.resumeLive();
    expect(g.mode, BattleMode.live);
    expect(g.scene.player.live, isTrue);
    expect(g.scene.effects.active, isEmpty);
    marching(5).forEach(feed.add);
    expect(g.scene.player.bufferedTicks, 5);
    g.onRemove();
    await feed.close();
  });

  test('수용 기준 7: 콘솔 요약 한 줄', () {
    final m = PerfMonitor();
    for (var i = 0; i < 600; i++) {
      m.add(i % 100 == 0 ? 40 : 16);
    }
    final line = m.takeSummary(SceneStats()..effects = 38);
    expect(
      line,
      matches(
        RegExp(r'^\[perf\] fps=[\d.]+ p50=[\d.]+ms p95=[\d.]+ms max=[\d.]+ms slow=6 fx=38 num=0 proj=0 coins=0$'),
      ),
    );
    expect(m.takeSummary(SceneStats()), contains('slow=0'));
  });
}

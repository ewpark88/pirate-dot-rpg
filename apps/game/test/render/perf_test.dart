import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/render/demo/sample_battle.g.dart';
import 'package:pirate_dot/render/demo/stress_recording.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/power_save_cache.dart';
import 'package:pirate_dot/render/perf/perf_monitor.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/viewport/integer_scale.dart';

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

    test('모든 틱에 화면 안 적 24 이상, 10틱마다 범위 처치', () {
      for (final t in a) {
        expect(t.frame.enemies.where((e) => e.x <= kLogicalWidth).length, greaterThanOrEqualTo(24));
      }
      var sinceAoe = 0;
      for (final t in a) {
        sinceAoe = t.events.any((e) => e is AoeDamageSum) ? 0 : sinceAoe + 1;
        expect(sinceAoe, lessThan(10 + 3), reason: '히트스톱 프레임(최대 3)을 빼면 10틱마다');
      }
      expect(a.any((t) => t.frame.hitStopTicks > 0), isTrue);
      expect(a.any((t) => t.events.any((e) => e is UltimateCast)), isTrue);
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

    test('갱신 없는 프레임은 같은 Picture를 다시 그린다', () {
      final cache = PowerSaveCache();
      void frame({required bool dirty}) {
        final rec = ui.PictureRecorder();
        cache.render(
          ui.Canvas(rec),
          dirty: dirty,
          paint: (c) => c.drawColor(const ui.Color(0xFF000000), ui.BlendMode.src),
        );
        rec.endRecording().dispose();
      }

      frame(dirty: true);
      frame(dirty: false);
      frame(dirty: false);
      frame(dirty: true);
      expect(cache.recorded, 2);
      expect(cache.reused, 2);
      cache.dispose();
    });
  });

  test('수용 기준 5: 정수배 확대', () {
    final a = integerScale(1080, 700);
    expect((a.scale, a.offsetX, a.offsetY), (3, (1080 - 960) / 2, (700 - 540) / 2));
    expect(integerScale(319, 200).scale, 1);
    expect(integerScale(1920, 1080).scale, 6);
    final hi = integerScale(400, 300, dpr: 2.5);
    expect(hi.scale * 2.5, 3, reason: '물리 픽셀 기준 정수배');
  });

  test('수용 기준 6: 부하 장면 → 라이브 복귀', () async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    final g = BattleGame(feed: feed.stream)..onGameResize(Vector2(kLogicalWidth * 2, kLogicalHeight * 2));
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

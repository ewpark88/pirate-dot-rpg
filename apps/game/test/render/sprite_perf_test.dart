import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/demo/stress_recording.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

/// 부하 장면 그리기 비용: 플레이스홀더 vs 아트 팩 스프라이트 (render-art-pack 규칙 6).
/// 테스트 환경 수치(소프트웨어 래스터)라 실기기와 다르다 — 상대 비교와 회귀 감시용. 결과는 콘솔 `[sprite-perf]`.
void main() {
  testWidgets('부하 장면 600프레임: 기록(record)·래스터(60장) 시간 비교', (tester) async {
    await tester.runAsync(() async {
      final bank = await SpriteBank.load(Images(prefix: 'assets/'), tables);
      final results = <String, (double, double)>{};
      for (final useSprites in [false, true]) {
        final scene = BattleScene(tables, stressRecording());
        final painter = ScenePainter(scene)
          ..sprites = bank
          ..useSprites = useSprites;
        final record = Stopwatch();
        final raster = Stopwatch();
        for (var f = 0; f < 600; f++) {
          scene.update(kFrameMs);
          record.start();
          final rec = ui.PictureRecorder();
          painter.paint(ui.Canvas(rec));
          final picture = rec.endRecording();
          record.stop();
          if (f % 10 == 0) {
            raster.start();
            (await picture.toImage(kLogicalWidth.toInt(), kLogicalHeight.toInt())).dispose();
            raster.stop();
          }
          picture.dispose();
        }
        final name = useSprites ? 'sprites' : 'placeholder';
        results[name] = (record.elapsedMicroseconds / 600 / 1000, raster.elapsedMicroseconds / 60 / 1000);
        debugPrint(
          '[sprite-perf] $name record=${results[name]!.$1.toStringAsFixed(3)}ms/frame '
          'raster=${results[name]!.$2.toStringAsFixed(3)}ms/frame (sprites loaded: ${bank.length})',
        );
      }
      // 회귀 감시: 스프라이트 기록 비용이 플레이스홀더의 5배를 넘지 않는다(이미지 캐시·필터 재사용 확인).
      expect(results['sprites']!.$1, lessThan(results['placeholder']!.$1 * 5 + 0.5));
    });
  });
}

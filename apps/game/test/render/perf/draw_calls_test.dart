// 프레임당 그리기 호출 수 (S1 절전·CPU 점검). 숫자는 출력만 하고, 상한은 느슨하게 지킨다(회귀 방지).
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/demo/sample_battle.g.dart';
import 'package:pirate_dot/render/demo/stress_recording.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/paint/stage_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/viewport/battle_frame.dart';

import '../helpers.dart';

/// 그리기 호출만 센다 (실제로 그리지 않는다).
class CountingCanvas implements Canvas {
  int calls = 0;
  final byName = <String, int>{};
  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    if (n.contains('draw') || n.contains('clip')) {
      calls++;
      byName[n] = (byName[n] ?? 0) + 1;
    }
    return null;
  }
}

void main() {
  for (final (name, rec) in [('demo', decodeRecording(sampleBattleJsonl)), ('stress', stressRecording())]) {
    testWidgets('그리기 호출 수: $name (S24)', (tester) async {
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      final scene = BattleScene(tables, rec, loop: true)..layout = battleFrameFor(const Size(384, 374), 2.8125);
      final painter = ScenePainter(scene)..sprites = bank;
      final stage = StagePainter(scene, SpriteDraw()..bank = bank);
      var total = 0;
      var bg = 0;
      const frames = 300;
      final names = <String, int>{};
      for (var f = 0; f < frames; f++) {
        scene.update(1000 / 60);
        final c = CountingCanvas();
        painter.paint(c);
        total += c.calls;
        c.byName.forEach((k, v) => names[k] = (names[k] ?? 0) + v);
        final b = CountingCanvas();
        stage.paintBackground(b);
        bg += b.calls;
      }
      // ignore: avoid_print
      print('[$name] 프레임당 그리기 ${total / frames} (배경 ${bg / frames}) ${names.map((k, v) => MapEntry(k, v / frames))}');
    });
  }
}

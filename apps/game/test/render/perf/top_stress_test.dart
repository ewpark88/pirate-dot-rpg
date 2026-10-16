// 탑다운 부하(S1: 화면 동시 적 수십~100, 렌더는 100~150마리에서 60fps): 150마리가 사방에서 배로 다가오며 매 틱 여러 발 발사.
// 숫자는 출력만, 상한은 느슨하게(회귀 방지): 프레임당 그리기 호출 수.
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/demo/stress_recording.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import '../helpers.dart';
import 'counting_canvas.dart';

Future<void> _measure(WidgetTester tester, String name, List<RecordedTick> rec, {double maxCalls = 900}) async {
  final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
  const box = Size(384, 684);
  final scene = BattleScene(tables, rec)..layout = battleFrameFor(box, 2.8125);
  final painter = ScenePainter(scene)..sprites = bank;
  final frame = topFrameFor(box, 2.8125);
  final warm = Canvas(PictureRecorder());
  for (var i = 0; i < 120; i++) {
    scene.update(kFrameMs);
    painter.paintTop(warm, frame);
  }
  var calls = 0;
  final names = <String, int>{};
  final sw = Stopwatch();
  const frames = 300;
  for (var i = 0; i < frames; i++) {
    scene.update(kFrameMs);
    final c = CountingCanvas();
    painter.paintTop(c, frame);
    calls += c.calls;
    c.byName.forEach((k, v) => names[k] = (names[k] ?? 0) + v);
    sw.start();
    painter.paintTop(warm, frame);
    sw.stop();
  }
  // 측정값을 남긴다(부하 전후 표).
  // ignore: avoid_print
  print(
    '[$name] 그리기 ${(calls / frames).toStringAsFixed(1)}/프레임, 기록 ${(sw.elapsedMicroseconds / frames / 1000).toStringAsFixed(2)}ms/프레임 (디버그 JIT, 상대 비교용)',
  );
  // 그리기 종류별 수를 남긴다(어디를 줄일지).
  // ignore: avoid_print
  print(
    '  ${names.map((k, v) => MapEntry(k.replaceAll('Symbol("', '').replaceAll('")', ''), (v / frames).toStringAsFixed(1)))}',
  );
  expect(calls / frames, lessThan(maxCalls));
}

void main() {
  testWidgets('탑다운 부하 150마리(대부분 화면 안)', (tester) => _measure(tester, 'top stress 150', stressRecording()));
  testWidgets(
    '탑다운 부하 150마리(사방 넓게 — 화면 밖 많음)',
    (tester) => _measure(tester, 'top stress 150 wide', stressRecording(spread: 300)),
  );
}

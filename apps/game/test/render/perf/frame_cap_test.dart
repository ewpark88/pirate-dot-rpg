import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/perf/frame_cap.dart';

void main() {
  test('절전 상한: 켜면 엔진 루프를 멈추고(타이머가 몬다), 끄면 되돌린다. 백그라운드면 타이머도 멈춘다', () {
    final game = FlameGame();
    final cap = FrameCap(game)..start(30);
    expect(game.paused, isTrue);
    expect(cap.active, isTrue);
    cap.suspend();
    expect(cap.active, isFalse);
    expect(game.paused, isTrue, reason: '백그라운드: 엔진도 타이머도 멈춤');
    cap.resume(30);
    expect(cap.active, isTrue);
    cap.stop();
    expect(game.paused, isFalse);
    expect(cap.active, isFalse);
  });
}

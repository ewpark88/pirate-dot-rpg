import 'dart:async';

import 'package:flame/game.dart';

/// 절전 fps 상한 (S5 실측: 전투 중 CPU 120~130%). Flame 게임 루프는 화면 주사율(60~120Hz)마다 update + 다시 그리기를 하므로,
/// 장면 진행만 줄여서는 래스터 스레드가 그대로 돈다. 상한이 켜지면 엔진 루프를 멈추고 타이머로 fps번만 한 프레임씩
/// 진행·그리기(stepEngine)를 한다 → Flutter도 그 프레임만 그린다. 앱이 백그라운드면 타이머도 멈춘다.
class FrameCap {
  FrameCap(this.game);

  final Game game;
  Timer? _timer;
  final _clock = Stopwatch();
  bool _suspended = false;

  /// 타이머가 프레임을 몰고 있는가 (그동안 update의 dt는 실제 경과 시간).
  bool get active => _timer != null;

  /// fps로 상한을 건다. 이미 걸려 있으면 그대로.
  void start(num fps) {
    if (_timer != null || _suspended) return;
    game.pauseEngine();
    _clock
      ..reset()
      ..start();
    _timer = Timer.periodic(Duration(microseconds: (Duration.microsecondsPerSecond / fps).round()), (_) {
      final dt = _clock.elapsedMicroseconds / Duration.microsecondsPerSecond;
      _clock
        ..reset()
        ..start();
      game.stepEngine(stepTime: dt);
    });
  }

  /// 상한을 풀고 엔진 루프(화면 주사율)로 돌아간다.
  void stop() {
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    _clock.stop();
    game.resumeEngine();
  }

  /// 앱이 백그라운드로 가면 타이머를 멈추고(엔진은 멈춘 채), 돌아오면 fps로 다시.
  void suspend() {
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    _suspended = true;
  }

  void resume(num fps) {
    if (!_suspended) return;
    _suspended = false;
    start(fps);
  }
}

import 'dart:math' as math;

import 'package:game_data/game_data.dart';

/// 화면 흔들림. 무작위 대신 정해진 파형을 써서 같은 기록이면 같은 화면(골든)이 나온다.
class ScreenShake {
  double _px = 0;
  double _ms = 0;
  double _age = 0;
  bool enabled = true;

  /// 마지막으로 건 흔들림의 최대 진폭(px). 끝나면 0.
  double get peak => amplitude > 0 ? _px : 0;

  /// 지금 진폭(px). 시간이 지나며 0으로 줄어든다.
  double get amplitude => _ms <= 0 || _age >= _ms ? 0 : _px * (1 - _age / _ms);

  /// 정수 픽셀 오프셋 (도트가 번지지 않게).
  double get offsetX => enabled ? (amplitude * math.sin(_age * _freqX)).roundToDouble() : 0;
  double get offsetY => enabled ? (amplitude * math.cos(_age * _freqY)).roundToDouble() : 0;

  static const _freqX = 0.09;
  static const _freqY = 0.13;

  /// 더 센 흔들림만 덮어쓴다 (약한 흔들림이 강한 것을 끊지 않게).
  void trigger(ShakeSpec spec) => triggerPx(spec.px, spec.ms);

  void triggerPx(double px, double ms) {
    if (!enabled || px < amplitude) return;
    _px = px;
    _ms = ms;
    _age = 0;
  }

  void update(double dtMs) {
    if (_age < _ms) _age += dtMs;
  }

  void reset() {
    _px = 0;
    _ms = 0;
    _age = 0;
  }
}

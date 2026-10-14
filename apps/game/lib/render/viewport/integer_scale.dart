import 'dart:math' as math;

import 'package:pirate_dot/render/layout.dart';

/// 정수배 확대 결과 (논리 픽셀). scale × devicePixelRatio가 정수다.
typedef IntegerScale = ({double scale, double offsetX, double offsetY});

/// 전장 위젯 [w]×[h](논리 픽셀)에 320×180을 물리 픽셀 기준 정수배로 넣는다. 최소 1배, 가운데 정렬.
/// BattleGame이 카메라 확대·위치를 이 값으로 맞춘다(비정수 배율인 withFixedResolution 대체).
IntegerScale integerScale(double w, double h, {double dpr = 1}) {
  final k = math.max(1, math.min(w * dpr / kLogicalWidth, h * dpr / kLogicalHeight).floor());
  final scale = k / dpr;
  return (scale: scale, offsetX: (w - kLogicalWidth * scale) / 2, offsetY: (h - kLogicalHeight * scale) / 2);
}

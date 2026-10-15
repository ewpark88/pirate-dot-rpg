import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/layout.dart';

/// 탑다운 전장 배치 (T2, 사용자 결정 '배는 화면 가운데·크게'). 렌더 카메라와 UI가 같은 계산을 쓴다.
///
/// - 배율 k = floor(물리 폭 / [kTopViewUnits]) — **폭으로만** 정한다. 상자 높이(시트를 끄는 동안 매 프레임 바뀜)는 k를 바꾸지 않는다.
/// - 단위(unit) = 전장 좌표 1. 1단위 = [dot] dp. 화면 가로 약 270단위(전장 폭).
/// - 선원 줄·궁극기·보스 도전 자리는 옆모습과 같은 [band](battleFrameFor) — UI는 그대로 slotRects 등을 쓴다.
/// - 배 중심은 보이는 전장(상자 위 ~ 선원 줄 위)의 가로 가운데·세로 [kShipAt] 지점: [shipScreen] (dp).
class TopFrame {
  TopFrame._({required this.k, required this.dpr, required this.box, required this.band});

  /// 화면 가로에 보이는 전장 단위 수 — 전장 폭(waves.top.width 270)과 같게(사용자 '배가 너무 크다·보스가 안 보인다':
  /// 배가 폭의 약 18%, 보스 궤도가 늘 보이게). S24 1단위 ≈ 1.42dp.
  static const double kTopViewUnits = 270;

  final int k;
  final double dpr;
  final Size box;

  /// 선원 줄·버튼 자리 (옆모습 배치를 그대로 씀).
  final BattleFrame band;

  /// 1단위의 dp 크기.
  double get dot => k / dpr;

  /// 보이는 전장 (dp): 상자 위 ~ 선원 줄 윗변.
  Rect get fieldDp => Rect.fromLTRB(0, 0, box.width, band.slotBand.top);

  /// 배 중심 높이 = 보이는 전장 위에서 [kShipAt] (사용자 지시 '가운데보다 아래 — 보스·진행 방향이 넓게 보이게').
  static const double kShipAt = 0.63;

  /// 배 중심이 그려지는 자리 (dp) — 가로 가운데, 세로는 보이는 전장의 [kShipAt] 지점.
  Offset get shipScreen => Offset(fieldDp.center.dx, fieldDp.top + fieldDp.height * kShipAt);

  /// 화면에 보이는 단위 수 (가로·세로, 상자 전체).
  Size get viewUnits => Size(box.width / dot, box.height / dot);

  /// 전장 좌표 → 상자 dp ([camera] = 화면 가운데 [cameraScreen]에 오는 전장 좌표).
  Offset toDp(Offset world, Offset camera, Offset cameraScreen) => cameraScreen + (world - camera) * dot;
}

/// [box](dp) 전장 상자의 탑다운 배치.
TopFrame topFrameFor(Size box, double dpr) {
  // 0.02 여유: 411dp × 2.625 = 1078.9처럼 한 칸 모자라 배율이 떨어지지 않게(보이는 폭이 180보다 아주 조금 작을 뿐).
  final k = math.max(1, (box.width * dpr / TopFrame.kTopViewUnits + 0.02).floor());
  return TopFrame._(k: k, dpr: dpr, box: box, band: battleFrameFor(box, dpr));
}

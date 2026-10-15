import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 내 배의 화면 자리 (그리는 쪽·발사 위치가 같은 계산). 등급 그림은 t1 상자 오른쪽 아래에 맞추고,
/// 뱃머리 오른쪽 끝·포구 높이(kShipPivotY)를 기준점으로 [scale]배 한다(사용자 지시 '배를 조금만 축소' → fx_map shipScale 1.3).
abstract final class ShipGeometry {
  /// 대포 레이어 프레임 크기(18×10, 그림 픽셀)와 포구 끝 줄(오른쪽 끝의 줄 4 윗변).
  static const cannonW = 18.0;
  static const cannonH = 10.0;
  static const cannonTipRow = 4.0;

  /// 포구 끝 = 대포 프레임 오른쪽 끝·줄 4 → 배 그림 오른쪽에서 3, 아래에서 22 (모든 등급 같음).
  static const _tipFromRight = 3.0;
  static const _tipFromBottom = 22.0;

  /// 배율: shipScale을 필드 배율 k에 맞춰 정수 물리 픽셀로 반올림(도트가 고르게, k=1 골든은 1배).
  static double scale(BattleScene s) {
    final k = s.layout.k;
    return math.max(1, (s.fx.raw.number('shipScale') * k).round()) / k;
  }

  /// 배 그림 프레임 [w]×[h] (그림 픽셀)이 그려지는 상자 (도트, 출렁임 제외).
  static Rect box(BattleScene s, double w, double h) => Rect.fromLTRB(
    _right - w * scale(s),
    _y(s, _bottom - h),
    _right,
    _y(s, _bottom),
  );

  /// 포구 끝 (도트, 출렁임 제외) — 발사체 출발점·포구 화염.
  static Offset cannonTip(BattleScene s) => Offset(_right - _tipFromRight * scale(s), _y(s, _bottom - _tipFromBottom));

  static const double _right = kShipLeft + kShipWidth;
  static const double _bottom = kShipTop + kShipHeight;
  static double _y(BattleScene s, double y) => kShipPivotY + (y - kShipPivotY) * scale(s);
}

import 'dart:math' as math;

import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';

/// 배 회전(그리기 각도): 엔진 shipHeading(피버 지그재그 ±25°)을 약 0.25초에 따라가고, 방향이 없으면 x 변화로 뱅크(최대 15°).
/// 방향을 바꾸면 큰 물보라. TopScenePainter에서 뺌(300줄).
class ShipTurn {
  ShipTurn(this.scene);

  final BattleScene scene;

  /// 지금 그리기 각도(라디안).
  double get angle => _heading + _bank;

  double _prevX = double.nan;
  double _bank = 0;
  double _heading = 0;
  double _vx = 0;

  /// 피버 좌우 이동: x 변화로 뱅크(이동 방향으로 최대 15°, 부드럽게), 방향을 바꾸면 큰 물보라.
  void update(double x, double clockMs, double dt) {
    if (_prevX.isNaN || dt <= 0) {
      _prevX = x;
      return;
    }
    final vx = (x - _prevX) / dt * Duration.millisecondsPerSecond;
    _prevX = x;
    if (_vx.abs() > 12 && vx.abs() > 12 && vx.sign != _vx.sign) {
      scene.topHits.impact.add(x, scene.topShip.dy + 6, 30, 0xFFE6F6FF, clockMs, water: true);
    }
    _vx = vx;
    final target = (vx / 90).clamp(-1.0, 1.0) * 15 * math.pi / 180;
    // 엔진이 배 방향(shipHeading, 피버 지그재그 ±25°)을 주면 그 각도로 — 꺾을 때 약 0.25초에 빠르게 돌고, x 변화 뱅크는 쓰지 않는다.
    final heading = scene.frame.shipHeading;
    _heading += (heading - _heading) * math.min(1, dt / 80);
    _bank += ((heading != 0 ? 0 : target) - _bank) * math.min(1, dt / 120);
  }
}

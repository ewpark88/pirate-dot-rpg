import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 탑다운(BattleView.mode 'top', T1) 장면 좌표 도우미. 배 중심은 전장 좌표(waves.top.shipX·shipY 기본).
extension TopView on BattleScene {
  bool get isTop => frame.mode == 'top';

  Offset get topShip => Offset(frame.shipX ?? tables.waves.top.shipX, frame.shipY ?? tables.waves.top.shipY);

  /// 내 배 가운데 (지금 방식의 좌표) — 피격 숫자·코인 목표.
  Offset get shipCenter => isTop ? topShip : const Offset(kShipCenterX, kShipCenterY);

  /// 코인이 날아갈 곳: 탑다운은 배, 옆모습은 UI 골드 자리(없으면 배).
  (double, double) get coinTo => isTop ? (topShip.dx, topShip.dy) : coinFlow.target(layout);

  /// 유리병(돌발 이벤트 bottle)이 떠 있는 자리 — 배 오른쪽 앞, 천천히 출렁임.
  Offset get bottleAt => topShip + Offset(30, -12 + math.sin(clockMs / 600) * 2);
}

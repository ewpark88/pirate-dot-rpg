import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/replay/recording_player.dart' show lerpAngle;
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 탑다운(BattleView.mode 'top', T1) 장면 좌표 도우미. 배 중심은 전장 좌표(waves.top.shipX·shipY 기본).
extension TopView on BattleScene {
  bool get isTop => frame.mode == 'top';

  /// 배 자리 — 틱 사이를 이어 그린다(모션 v1: 20Hz 계단처럼 뚝뚝 움직이던 것).
  Offset get topShip {
    final w = tables.waves.top;
    final a = Offset(frame.shipX ?? w.shipX, frame.shipY ?? w.shipY);
    final b = player.nextFrame;
    if (b == null) return a;
    return Offset.lerp(a, Offset(b.shipX ?? w.shipX, b.shipY ?? w.shipY), player.fraction)!;
  }

  /// 배 방향(엔진 shipHeading)도 틱 사이를 가까운 쪽으로 잇는다.
  double get topHeading {
    final b = player.nextFrame;
    return b == null ? frame.shipHeading : lerpAngle(frame.shipHeading, b.shipHeading, player.fraction);
  }

  /// 탑다운 카메라 중심(전장 좌표): 바다 가운데 고정(waves.top.shipX·shipY). 피버 지그재그(S5)·빠른 항해 때 배만 화면에서 움직인다.
  Offset get topCamera => Offset(tables.waves.top.shipX, tables.waves.top.shipY);

  /// 내 배 가운데 (지금 방식의 좌표) — 피격 숫자·코인 목표.
  Offset get shipCenter => isTop ? topShip : const Offset(kShipCenterX, kShipCenterY);

  /// 코인이 날아갈 곳: 탑다운은 배, 옆모습은 UI 골드 자리(없으면 배).
  (double, double) get coinTo => isTop ? (topShip.dx, topShip.dy) : coinFlow.target(layout);

  /// 유리병(돌발 이벤트 bottle)이 떠 있는 자리 — 배 오른쪽 앞, 천천히 출렁임.
  Offset get bottleAt => topShip + Offset(30, -12 + math.sin(clockMs / 600) * 2);
}

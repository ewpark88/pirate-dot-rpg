import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';

/// 보상 코인의 도착지와 알림 (사용자 지시 '돈 들어오는 게 보이게'). UI(S4)와의 약속:
/// - [goldTargetDp]: 상단 바 골드 아이콘 자리, 전장 상자 왼쪽 위 기준 dp(상자 위면 y < 0). null이면 배로.
/// - [onCoinArrive]: 코인이 닿은 프레임마다 그 프레임 금액 합계 — UI가 아이콘 통통·'+금액'.
class CoinFlow {
  Offset? goldTargetDp;
  void Function(BigNum amount)? onCoinArrive;

  /// 날아갈 곳 (도트). 상자 위 자리는 보이는 맨 위 바로 위로 묶는다(캔버스는 상자 밖을 못 그린다).
  (double, double) target(BattleFrame layout) {
    final t = goldTargetDp;
    if (t == null) return (kCoinTargetX, kCoinTargetY);
    final v = layout.viewDots;
    return (v.left + t.dx / layout.dot, math.max(v.top - 6, v.top + t.dy / layout.dot));
  }
}

import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';

// 보스 처치 코인 비: 화면 위 결정론적 x에서 떨어져 배(또는 UI 골드)로 (render-regions 규칙 5).
// 옆모습은 필드 위, 탑다운은 배 위쪽 화면 폭에서.
const _rainLeft = 70.0;
const _rainSpan = 240;
const _rainPrime = 37;
const _rainTopY = -4.0;
const _rainFallMin = 60.0;
const _rainFallSpread = 40;
const _topHalfSpan = 80.0;
const _topAbove = 150.0;

void coinRain(BattleScene scene) {
  final j = scene.juice;
  final top = scene.isTop;
  final ship = scene.topShip;
  // 보이는 폭 안에서만 (필드를 키우면 오른쪽이 잘린다).
  final span = top
      ? (_topHalfSpan * 2).toInt()
      : math.min(_rainSpan, (scene.layout.visibleRight - _rainLeft - 8).floor());
  final left = top ? ship.dx - _topHalfSpan : _rainLeft;
  final y0 = top ? ship.dy - _topAbove : _rainTopY;
  final (tx, ty) = scene.coinTo;
  for (var i = 0; i < j.bossCoinRain; i++) {
    final x = left + i * _rainPrime % span;
    scene.coins.obtain()
      ..fromX = x
      ..fromY = y0
      ..toX = tx
      ..toY = ty
      ..amount = BigNum.zero
      ..spread = 0
      ..lift = 0
      ..fallPx = _rainFallMin + i * _rainPrime % _rainFallSpread
      ..ageMs = -(i * j.coinFlyMs / j.bossCoinRain)
      ..flyMs = j.coinFlyMs * 2
      ..x = x
      ..y = y0;
  }
}

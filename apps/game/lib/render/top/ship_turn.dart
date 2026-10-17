import 'dart:math' as math;
import 'dart:ui';

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
  double _sprayAt = -1000000000;

  /// 배 빠르기(단위/초, 부드럽게) — S5 배 이동 v2(돌진·대시)를 엔진 키 없이 자리 변화로 읽는다.
  double speed = 0;
  Offset? _prevPos;

  /// 질주 정도 0~1(60단위/초부터 180에 가득): 항적 길이·잔상·속도선(TopScenePainter).
  double get rush => ((speed - 60) / 120).clamp(0.0, 1.0);

  /// 피버 좌우 이동: x 변화로 뱅크(이동 방향으로 최대 15°, 부드럽게), 방향을 바꾸면 큰 물보라.
  void update(double x, double clockMs, double dt) {
    _speed(clockMs, dt);
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
    final heading = scene.topHeading;
    final before = _heading;
    // 보스전 v2(S5: 배가 보스를 마주 보며 돈다)는 방향이 한 바퀴를 넘나든다 — 가까운 쪽으로 돌게 차이를 −π~π로.
    var diff = (heading - _heading) % (2 * math.pi);
    if (diff > math.pi) diff -= 2 * math.pi;
    _heading += diff * math.min(1, dt / 80);
    // 피버 8자 곡선(S5): 크게 꺾는 동안 0.11초마다 바깥쪽으로 물보라가 튄다(사용자 '물보라가 약하다').
    final rate = (_heading - before) / dt;
    if (rate.abs() > 0.0012 && clockMs - _sprayAt > 110) {
      _sprayAt = clockMs;
      final out = scene.topHeading - math.pi / 2 + (rate > 0 ? -math.pi / 2 : math.pi / 2);
      final at = scene.topShip + Offset(math.cos(out) * 16, math.sin(out) * 16 + 6);
      scene.topHits.impact.add(at.dx, at.dy, 18, 0xFFE6F6FF, clockMs, water: true);
    }
    _bank += ((heading != 0 ? 0 : target) - _bank) * math.min(1, dt / 120);
  }

  /// 빠르기를 재고, 질주가 시작되는 순간(0.5를 넘을 때) 고물 양옆에 큰 물보라.
  void _speed(double clockMs, double dt) {
    final p = scene.topShip;
    final prev = _prevPos;
    _prevPos = p;
    if (prev == null || dt <= 0) return;
    final was = rush;
    final v = (p - prev).distance / dt * Duration.millisecondsPerSecond;
    speed += ((v > 600 ? speed : v) - speed) * math.min(1, dt / 150); // 순간이동(장면 바뀜)은 무시
    if (was < 0.5 && rush >= 0.5) {
      for (final s in const [-1.0, 1.0]) {
        scene.topHits.impact.add(p.dx + s * 14, p.dy + 12, 34, 0xFFE6F6FF, clockMs, water: true);
      }
    }
  }
}

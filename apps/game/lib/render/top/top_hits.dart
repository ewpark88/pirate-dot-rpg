import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';

/// 탑다운 배 충돌 연출 (사용자 '적들이 배에 부딪히지 않는다' — 엔진은 닿는데 눈에 안 보였다, S1):
/// 때린 적이 배 쪽으로 툭 박고(돌진), 닿은 자리에 물보라·나뭇조각이 튄다. 엔진 무관 — ShipDamaged fromX/fromY.
class TopHits {
  /// 적 id → 돌진 시작 시각(장면 ms).
  final Map<int, double> _lunge = {};
  final List<_Spot> _spots = [];

  static const lungeMs = 120.0;
  static const lungeUnits = 4.0;
  static const spotMs = 420.0;
  static const _maxSpots = 12;

  /// 배가 (fromX, fromY)에서 맞음: 가장 가까운 적이 돌진, 선체 가장자리(배 중심에서 그쪽으로 최대 12단위)에 물보라.
  void hit(BattleScene s, double fromX, double fromY) {
    final now = s.clockMs;
    var best = -1;
    var bestD = double.infinity;
    for (var k = 0; k < s.poseCount; k++) {
      final e = s.poses[k];
      final d = (e.x - fromX) * (e.x - fromX) + (e.y - fromY) * (e.y - fromY);
      if (d < bestD) (best, bestD) = (e.id, d);
    }
    if (best >= 0) _lunge[best] = now;
    final ship = s.topShip;
    final dx = fromX - ship.dx;
    final dy = fromY - ship.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final reach = math.min<double>(len, 12);
    final at = len < 1e-6 ? ship : ship + Offset(dx / len * reach, dy / len * reach);
    if (_spots.length >= _maxSpots) _spots.removeAt(0);
    _spots.add(_Spot(at.dx, at.dy, now, math.atan2(dy, dx)));
    if (_lunge.length > 64) _lunge.removeWhere((_, t) => now - t > lungeMs);
  }

  double _flashAt = -1000000000;
  static const _flashGapMs = 300.0;

  /// 배 번쩍을 새로 켜도 되는가(연달아 맞을 때 배가 계속 하얗게 보이지 않게 [_flashGapMs]마다 한 번). 켜면 시각을 적는다.
  bool takeFlash(double now) {
    if (now - _flashAt < _flashGapMs) return false;
    _flashAt = now;
    return true;
  }

  /// 적 [id]의 돌진 거리(단위, 0이면 없음): 앞으로 갔다 돌아옴 sin(π·t).
  double lungeOf(int id, double now) {
    final t0 = _lunge[id];
    if (t0 == null) return 0;
    final t = (now - t0) / lungeMs;
    if (t < 0 || t >= 1) return 0;
    return lungeUnits * math.sin(math.pi * t);
  }

  final _paint = Paint()..isAntiAlias = false;
  static const _chip = [0xFF8A5A30, 0xFFB57B44, 0xFF6B4423];

  /// 물보라(흰·하늘 점이 둥글게 퍼짐)·나뭇조각(배 바깥쪽으로 튐)·작은 번쩍. 전장 좌표.
  void paint(Canvas c, double now, {required bool flash}) {
    _spots.removeWhere((p) => now - p.ms >= spotMs);
    for (final p in _spots) {
      final t = ((now - p.ms) / spotMs).clamp(0.0, 1.0);
      final fade = 1 - t;
      if (flash && t < 0.25) {
        _paint.color = Color.fromARGB((200 * (1 - t / 0.25)).round(), 255, 255, 255);
        c.drawCircle(Offset(p.x, p.y), 5 * (1 - t), _paint);
      }
      for (var k = 0; k < 8; k++) {
        final a = p.angle + k * math.pi / 4 + 0.2;
        final r = 3 + 9 * t;
        _paint.color = Color.fromARGB((255 * fade).round(), k.isEven ? 255 : 190, k.isEven ? 255 : 232, 255);
        final size = t < 0.5 ? 2.0 : 1.0;
        c.drawRect(
          Rect.fromLTWH((p.x + math.cos(a) * r).roundToDouble(), (p.y + math.sin(a) * r).roundToDouble(), size, size),
          _paint,
        );
      }
      for (var k = 0; k < 4; k++) {
        final a = p.angle + (k - 1.5) * 0.45;
        final r = 2 + 13 * t;
        _paint.color = Color(_chip[k % 3]).withValues(alpha: fade);
        c.drawRect(
          Rect.fromLTWH((p.x + math.cos(a) * r).roundToDouble(), (p.y + math.sin(a) * r).roundToDouble(), 2, 1),
          _paint,
        );
      }
    }
  }

  void clear() {
    _flashAt = -1000000000;
    _lunge.clear();
    _spots.clear();
  }
}

class _Spot {
  _Spot(this.x, this.y, this.ms, this.angle);
  final double x;
  final double y;
  final double ms;
  final double angle;
}

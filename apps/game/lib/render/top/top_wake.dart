import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/top/ship_turn.dart';

/// 배가 바다를 도는 항적(S5 배 이동 v2 · S1 '배가 느려서 재미없다'): 고물 자리를 35ms마다 남겨 굵은 흰 물보라 꼬리로 —
/// 오래될수록 퍼지며 옅어지고, 빠를수록(질주 rush) 길고 굵다. 돌진(rush 0.5↑) 땐 배 양옆으로 진행 방향 속도선.
/// 전장 좌표(배 아래·적 아래에 그린다).
class TopWake {
  final List<(Offset, double, double)> _pts = []; // 고물 자리, ms, 그때 질주 정도
  final _foam = Paint()..isAntiAlias = true;
  final _line = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round;
  static const _baseMs = 520.0;
  static const _max = 48;

  Offset _ship = Offset.zero;
  double _angle = 0;
  double _rush = 0;

  /// 배 자리 [ship]·그리기 각도 [angle](0 = 위)·빠르기 [speed](단위/초)·질주 [rush].
  void update(Offset ship, double angle, double speed, double rush, double now, {required bool lite}) {
    _ship = ship;
    _angle = angle;
    _rush = rush;
    final life = _baseMs * (1 + 1.2 * rush);
    _pts.removeWhere((p) => now - p.$2 > life || now < p.$2);
    if (speed < 18) return; // 거의 멈추면 꼬리를 새로 남기지 않는다(남은 것은 사라진다)
    if (_pts.isNotEmpty && now - _pts.last.$2 < (lite ? 70 : 35)) return;
    final stern = ship + Offset(-math.sin(angle) * 15, math.cos(angle) * 15);
    if (_pts.length >= _max) _pts.removeAt(0);
    _pts.add((stern, now, rush));
  }

  void paint(Canvas c, double now, Offset ship, ShipTurn turn, {required bool lite}) {
    update(ship, turn.angle, turn.speed, turn.rush, now, lite: lite);
    final life = _baseMs * (1 + 1.2 * _rush);
    for (final (p, at, r) in _pts) {
      final t = ((now - at) / life).clamp(0.0, 1.0);
      final rad = (4.5 + 8 * t) * (1 + 0.5 * r);
      _foam.color = Color.fromRGBO(240, 252, 255, 0.8 * (1 - t) * (0.6 + 0.4 * r));
      c.drawCircle(p, rad, _foam);
    }
    if (_rush < 0.5) return;
    // 돌진 속도선: 배 양옆에서 뒤로 길게(진행 방향과 나란히), 흔들리며 깜빡임.
    final k = (_rush - 0.5) / 0.5;
    final back = Offset(-math.sin(_angle), math.cos(_angle));
    final side = Offset(back.dy, -back.dx);
    for (var i = 0; i < 6; i++) {
      final off = (i - 2.5) * 9.0 + math.sin(now / 60 + i) * 2;
      final start = _ship + side * off + back * (10 + (i % 3) * 6.0);
      final len = (22 + (i % 2) * 14) * k;
      _line
        ..strokeWidth = 1.6
        ..color = Color.fromRGBO(255, 255, 255, 0.55 * k * (0.6 + 0.4 * math.sin(now / 45 + i * 1.7).abs()));
      c.drawLine(start, start + back * len, _line);
    }
  }

  void clear() => _pts.clear();
}

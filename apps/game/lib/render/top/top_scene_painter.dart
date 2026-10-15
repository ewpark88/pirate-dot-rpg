import 'dart:math' as math;
import 'dart:ui';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/render/top/top_sea_painter.dart';
import 'package:pirate_dot/render/top/top_ship_painter.dart';

/// 탑다운 장면 (T2): 배 가운데 고정 카메라 → 바다(흐름) → 항적 → 배(그림자·층). 적·발사체·숫자는 다음 단계에서 이 위에.
/// 상자 dp 좌표로 받은 캔버스에 그린다. 배 화면 자리는 보이는 전장 가운데 — 시트를 열어 보이는 전장이 줄면
/// [_followMs]에 걸쳐 부드럽게 따라간다(k는 폭으로만 정해 그대로).
class TopScenePainter {
  TopScenePainter(this.tables, this.sprites);

  final GameTables tables;
  final SpriteDraw sprites;
  late final TopSeaPainter _sea = TopSeaPainter(tables.fxMap.raw.obj('topSea'));
  late final TopShipPainter _ship = TopShipPainter(sprites);

  double? _shipY;
  double _lastMs = 0;
  static const _followMs = 220.0;

  /// [view] = 지금 화면 프레임(mode 'top'), [tierId] = 배 등급, [clockMs] = 장면 시계.
  void paint(Canvas c, TopFrame frame, BattleView view, String tierId, double clockMs) {
    final dt = (clockMs - _lastMs).clamp(0.0, 100.0);
    _lastMs = clockMs;
    final target = frame.shipScreen.dy;
    final y = _shipY ?? target;
    _shipY = y + (target - y) * math.min(1, dt / _followMs * 3);
    // 배 화면 자리를 물리 픽셀 정수로 (도트가 흔들리지 않게)
    final dpr = frame.dpr;
    final sx = (frame.shipScreen.dx * dpr).roundToDouble() / dpr;
    final sy = (_shipY! * dpr).roundToDouble() / dpr;
    final dot = frame.dot;
    final heading = view.shipHeading;
    c
      ..save()
      ..clipRect(Offset.zero & frame.box)
      ..translate(sx, sy)
      ..scale(dot);
    final viewRect = Rect.fromLTWH(-sx / dot, -sy / dot, frame.box.width / dot, frame.box.height / dot);
    _sea
      ..advance(clockMs, heading)
      ..paint(c, viewRect, clockMs);
    c.rotate(heading);
    final size = _ship.sizeOf(tierId);
    if (size != null) {
      _sea.wake(c, size.height / 2 - 4, size.height / 2, size.width / 2 * 0.6, clockMs);
      _ship.paint(c, tierId, view.shipLook);
    }
    c.restore();
  }
}

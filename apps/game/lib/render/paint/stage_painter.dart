import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 해역 배경(하늘·바다·깊은 바다 + 원경 장식)과 보스 경고·실패 덮개 (docs/specs/render-regions.md).
class StagePainter {
  StagePainter(this.scene);

  final BattleScene scene;
  final _paint = Paint()..isAntiAlias = false;

  void _rect(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l, t, w, h), _paint);
  }

  void paintBackground(Canvas c) {
    final b = scene.backdrop;
    _rect(c, 0, 0, kLogicalWidth, kHorizonY, b.sky);
    _decor(c, b.decor, b.decorColor);
    _rect(c, 0, kHorizonY, kLogicalWidth, kWaterlineY - kHorizonY, b.sea);
    _rect(c, 0, kWaterlineY, kLogicalWidth, kFieldBottom - kWaterlineY, b.deep);
  }

  // 원경 장식: 수평선 위에 단색 사각 몇 개 (아트가 오면 원경 이미지로 바뀐다).
  static const _decorShapes = <String, List<(double, double, double, double)>>{
    'islands': [(120, 56, 30, 8), (128, 50, 12, 6), (250, 58, 22, 6)],
    'clouds': [(60, 10, 70, 12), (150, 18, 90, 14), (260, 8, 50, 10)],
    'icebergs': [(100, 48, 24, 16), (108, 40, 10, 8), (230, 52, 30, 12)],
    'smoke': [(200, 20, 14, 36), (196, 10, 22, 12), (214, 2, 18, 10)],
    'fog': [(0, 50, 320, 6), (40, 42, 120, 4), (200, 44, 100, 4)],
  };

  void _decor(Canvas c, String decor, int color) {
    final shapes = _decorShapes[decor];
    if (shapes == null) return;
    for (final (l, t, w, h) in shapes) {
      _rect(c, l, t, w, h, color);
    }
  }

  /// 흔들림 밖에서 그리는 덮개: 보스 실패 어두움, 보스 등장 붉은 테두리(깜빡임).
  void paintOverlays(Canvas c) {
    final fx = scene.fx;
    if (scene.bossFailMs > 0) {
      final a = (fx.bossFailed.number('alpha') * 0xFF).round();
      _rect(c, 0, 0, kLogicalWidth, kFieldBottom, a << 24);
    }
    if (scene.bossWarnMs > 0) {
      final e = fx.bossEntrance;
      final period = e.number('ms') / (e.integer('blinks') * 2);
      final on = ((e.number('ms') - scene.bossWarnMs) / period).floor().isEven;
      if (!on) return;
      final px = e.number('borderPx');
      final color = _warnColor ??= parseArgb(e.str('color'), 'bossEntrance.color');
      _rect(c, 0, 0, kLogicalWidth, px, color);
      _rect(c, 0, kFieldBottom - px, kLogicalWidth, px, color);
      _rect(c, 0, 0, px, kFieldBottom, color);
      _rect(c, kLogicalWidth - px, 0, px, kFieldBottom, color);
    }
  }

  int? _warnColor;
}

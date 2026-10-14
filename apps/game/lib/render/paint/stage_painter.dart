import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 해역 배경(하늘·바다·깊은 바다 + 원경 장식)과 보스 경고·실패 덮개 (docs/specs/render-regions.md).
class StagePainter {
  StagePainter(this.scene, this.sprites);

  final BattleScene scene;
  final SpriteDraw sprites;
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

  late final int _chestColor = parseArgb(scene.fx.chest.str('color'), 'chest.color');
  late final int _lidColor = parseArgb(scene.fx.chest.str('lidColor'), 'chest.lidColor');
  static const _sinkFade = 0.7;
  static const _lidRatio = 0.35;

  /// 보물상자: 몸통 + 뚜껑 띠. 가라앉을수록 흐려진다. 탭 판정은 UI가 같은 좌표(중심 x·y)로.
  void paintChest(Canvas c) {
    final ch = scene.chest;
    if (!ch.visible) return;
    final w = scene.fx.chest.number('w');
    final h = scene.fx.chest.number('h');
    final a = ((1 - _sinkFade * ch.sink) * 0xFF).round() << 24;
    final l = (ch.x - w / 2).roundToDouble();
    final t = (ch.y - h / 2).roundToDouble();
    _rect(c, l, t, w, h, a | (_chestColor & 0xFFFFFF));
    _rect(c, l, t, w, (h * _lidRatio).roundToDouble(), a | (_lidColor & 0xFFFFFF));
  }

  /// 해역 보스 첫 등장 컷인: 어두운 띠가 오른쪽에서 들어와 머물다 왼쪽으로 빠진다(render-moments 규칙 2).
  void paintCutIn(Canvas c) {
    final cut = scene.moments.cutIn;
    if (!cut.active) return;
    final cfg = scene.fx.cutIn;
    final inMs = cfg.number('inMs');
    final holdMs = cfg.number('holdMs');
    final outMs = cfg.number('outMs');
    final age = cut.ageMs;
    final x = age < inMs
        ? kLogicalWidth * (1 - age / inMs)
        : age < inMs + holdMs
        ? 0.0
        : -kLogicalWidth * ((age - inMs - holdMs) / outMs);
    final h = cfg.number('bandH');
    final top = kFieldBottom / 2 - h / 2;
    final band = parseArgb(cfg.str('bandColor'), 'cutIn.bandColor');
    _rect(c, x, top, kLogicalWidth, h, ((cfg.number('bandAlpha') * 0xFF).round() << 24) | (band & 0xFFFFFF));
    final line = parseArgb(cfg.str('lineColor'), 'cutIn.lineColor');
    _rect(c, x, top, kLogicalWidth, 1, line);
    _rect(c, x, top + h - 1, kLogicalWidth, 1, line);
    final kind = cut.kind!;
    final scale = cfg.number('bossScale');
    final cx = x + kLogicalWidth / 2;
    final sheet = sprites.sheet('boss:$kind');
    if (sheet != null) {
      sprites.draw(c, 'boss:$kind', cx, top + h / 2, w: sheet.frameW * scale / 2, h: sheet.frameH * scale / 2);
      return;
    }
    final shape = scene.looks.bossOf(kind, boss: true)!;
    final bw = (shape.w * scale / 2).clamp(0.0, h * 2);
    final bh = (shape.h * scale / 2).clamp(0.0, h - 4);
    _rect(c, cx - bw / 2, top + h / 2 - bh / 2, bw, bh, shape.color);
  }

  /// 흔들림 밖에서 그리는 덮개: 보스 실패 어두움, 보스 등장 붉은 테두리(깜빡임), 컷인.
  void paintOverlays(Canvas c) {
    paintCutIn(c);
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

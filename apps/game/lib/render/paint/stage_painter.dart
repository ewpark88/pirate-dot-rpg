import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 해역 배경과 보스 경고·실패 덮개, 보물상자, 컷인 (render-regions · render-quality-v1).
/// 배경은 기준 battle_ship.gif 구조 그대로: 하늘 띠 4단 + 흐르는 타원 구름 + 바다 띠 3단 + 움직이는 물결 대시.
class StagePainter {
  StagePainter(this.scene, this.sprites);

  final BattleScene scene;
  final SpriteDraw sprites;
  final _paint = Paint()..isAntiAlias = false;

  void _rect(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l, t, w, h), _paint);
  }

  JsonReader get _l => scene.fx.backgroundLayout;
  late final List<double> _skyY = [for (final v in _l.raw['skyY'] as List) (v as num).toDouble()];
  late final List<double> _seaY = [for (final v in _l.raw['seaY'] as List) (v as num).toDouble()];
  late final List<double> _waveRows = [for (final v in _l.raw['waveRows'] as List) (v as num).toDouble()];
  late final List<double> _waveSpeed = [for (final v in _l.raw['waveSpeed'] as List) (v as num).toDouble()];
  late final List<(double, double, double)> _clouds = [
    for (final c in (_l.raw['clouds'] as List).cast<List<dynamic>>())
      ((c[0] as num).toDouble(), (c[1] as num).toDouble(), (c[2] as num).toDouble()),
  ];
  late final double _waveSplit = _l.number('waveSplitY');
  late final int _waveGap = _l.integer('waveGap');
  late final double _waveLen = _l.number('waveLen');
  late final double _cloudSpeed = _l.number('cloudSpeed');
  late final double _squash = _l.number('cloudSquash');

  void paintBackground(Canvas c) {
    final b = scene.backdrop;
    final t = scene.clockMs / Duration.millisecondsPerSecond;
    for (var i = 0; i < _skyY.length; i++) {
      final bottom = i + 1 < _skyY.length ? _skyY[i + 1] : _seaY.first;
      _rect(c, 0, _skyY[i], kLogicalWidth, bottom - _skyY[i], b.sky(i));
    }
    _paint.color = Color(b.cloud);
    for (final (x0, cy, r) in _clouds) {
      final cx = (x0 - t * _cloudSpeed) % (kLogicalWidth + 40) - 20;
      _cloud(c, cx, cy, r);
    }
    for (var i = 0; i < _seaY.length; i++) {
      final bottom = i + 1 < _seaY.length ? _seaY[i + 1] : kFieldBottom;
      _rect(c, 0, _seaY[i], kLogicalWidth, bottom - _seaY[i], b.sea(i));
    }
    for (final y in _waveRows) {
      final upper = y < _waveSplit;
      _paint.color = Color(b.wave(upper ? 0 : 1));
      final speed = _waveSpeed[upper ? 0 : 1];
      for (var x = -16; x < kLogicalWidth + 16; x += _waveGap) {
        final xx = (x + t * speed).floor() % (kLogicalWidth.toInt() + 32) - 16;
        final l = xx < 0 ? 0.0 : xx.toDouble();
        final r = xx + _waveLen > kLogicalWidth ? kLogicalWidth : xx + _waveLen;
        if (r > l) c.drawRect(Rect.fromLTWH(l, y, r - l, 1), _paint);
      }
    }
  }

  /// 타원 구름: (x−cx)² + ((y−cy)·squash)² < r² 인 픽셀 (기준과 같은 모양).
  void _cloud(Canvas c, double cx, double cy, double r) {
    final rows = (r / _squash).ceil();
    for (var dy = -rows; dy <= rows; dy++) {
      final y = cy + dy;
      final rest = r * r - (dy * _squash) * (dy * _squash);
      if (rest <= 0) continue;
      final hw = math.sqrt(rest);
      final left = (cx - hw).floor() + 1;
      final right = (cx + hw).ceil() - 1;
      if (right >= left) c.drawRect(Rect.fromLTWH(left.toDouble(), y, (right - left + 1).toDouble(), 1), _paint);
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

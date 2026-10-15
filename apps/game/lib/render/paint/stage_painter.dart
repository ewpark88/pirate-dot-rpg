import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/background_paths.dart';
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
  late final _paths = BackgroundPaths(squash: _squash, waveGap: _waveGap, waveLen: _waveLen);
  BattleFrame? _pathsFrame;

  /// 보이는 영역 전체를 채운다(화면 배치 v2): 맨 위 하늘 띠는 위로, 마지막 바다 띠는 선원 줄까지 아래로 늘이고,
  /// 구름·물결은 보이는 폭 전체에서 돈다. 깊은 바다(필드 아래)에도 어두운 물결 줄을 더한다.
  void paintBackground(Canvas c) {
    final b = scene.backdrop;
    final t = scene.clockMs / Duration.millisecondsPerSecond;
    final v = scene.layout.viewDots;
    final bottom = scene.layout.bandTop;
    if (!identical(_pathsFrame, scene.layout)) {
      _paths.reset();
      _pathsFrame = scene.layout;
    }
    for (var i = 0; i < _skyY.length; i++) {
      final top = i == 0 ? v.top : _skyY[i];
      final end = i + 1 < _skyY.length ? _skyY[i + 1] : _seaY.first;
      _rect(c, v.left, top, v.width + 1, end - top, b.sky(i));
    }
    _paint.color = Color(b.cloud);
    final span = v.width + 40;
    for (final (x0, cy, r) in _clouds) {
      final cx = (x0 - v.left - t * _cloudSpeed) % span - 20 + v.left;
      _cloud(c, cx, cy, r);
      if (v.top < -_highCloudRoom) _cloud(c, (cx + span / 2 - v.left) % span + v.left - 20, cy - _highCloudLift, r);
    }
    for (var i = 0; i < _seaY.length; i++) {
      final end = i + 1 < _seaY.length ? _seaY[i + 1] : bottom;
      _rect(c, v.left, _seaY[i], v.width + 1, end - _seaY[i], b.sea(i));
    }
    _deepSea(c, t, v, bottom);
    // 물결: 같은 속도·색 줄 묶음(위 바다 / 아래 바다 / 깊은 바다)마다 Path 1개를 흐름만큼 옮겨 그린다.
    c
      ..save()
      ..clipRect(Rect.fromLTRB(v.left, v.top, v.right, bottom));
    for (var g = 0; g < 3; g++) {
      final speed = _waveSpeed[g == 0 ? 0 : 1] * (g == 2 ? _deepWaveSlow : 1);
      final shift = (t * speed).floor() % _waveGap;
      _paint.color = Color(b.wave(g == 0 ? 0 : 1));
      c
        ..save()
        ..translate(v.left - 16 + shift, 0)
        ..drawPath(_paths.waves(g, _waveGroup(g, bottom), v.width + 32), _paint)
        ..restore();
    }
    c.restore();
  }

  /// 물결 줄 묶음 [g]: 0 = 위 바다(빠름), 1 = 아래 바다, 2 = 깊은 바다(필드 아래, 느림).
  List<double> _waveGroup(int g, double bottom) => switch (g) {
    0 => [
      for (final y in _waveRows)
        if (y < _waveSplit) y,
    ],
    1 => [
      for (final y in _waveRows)
        if (y >= _waveSplit && y <= kFieldBottom) y,
    ],
    _ => [for (var y = kFieldBottom + _deepWaveGap / 2; y < bottom - 2; y += _deepWaveGap) y],
  };

  /// 깊은 바다(필드 아래 ~ 선원 줄 위): 아주 옅은 빛줄기(비스듬, 천천히 흔들림)와 느리게 오르는 거품 몇 개.
  void _deepSea(Canvas c, double t, Rect v, double bottom) {
    final top = _seaY.first + 6;
    if (bottom - kFieldBottom < _deepMin) return;
    _paint.color = const Color(_rayColor);
    final ray = _paths.ray(top, bottom, _rayW);
    for (var i = 0; i < _rays; i++) {
      final x0 = v.left + v.width * (i + 0.5) / _rays + math.sin(t * 0.4 + i * 1.7) * 6;
      c
        ..save()
        ..translate(x0.floorToDouble(), 0)
        ..drawPath(ray, _paint)
        ..restore();
    }
    _paint.color = const Color(_bubbleColor);
    final span = bottom - kFieldBottom;
    for (var i = 0; i < _bubbles; i++) {
      final x = (v.left + (i * 53 + 17) % v.width.floor() + math.sin(t * 1.3 + i) * 1.5).floorToDouble();
      final y = (bottom - 2 - ((t * (3 + i % 3) + i * 11) % span)).floorToDouble();
      final s = i % 3 == 0 ? 2.0 : 1.0;
      c.drawRect(Rect.fromLTWH(x, y, s, s), _paint);
    }
  }

  static const _deepMin = 12.0;
  static const _rays = 3;
  static const _rayW = 3.0;
  static const _rayColor = 0x0FFFFFFF;
  static const _bubbles = 9;
  static const _bubbleColor = 0x55BFF3FF;

  static const _highCloudRoom = 24.0;
  static const _highCloudLift = 40.0;
  static const _deepWaveGap = 10.0;
  static const _deepWaveSlow = 0.5;

  /// 타원 구름: (x−cx)² + ((y−cy)·squash)² < r² 인 픽셀 (기준과 같은 모양) — 미리 만든 Path를 정수 자리로 옮겨 1번에.
  void _cloud(Canvas c, double cx, double cy, double r) => c
    ..save()
    ..translate(cx.floorToDouble(), cy)
    ..drawPath(_paths.cloud(r), _paint)
    ..restore();

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
    final v = scene.layout.viewDots;
    final x =
        v.left +
        (age < inMs
            ? v.width * (1 - age / inMs)
            : age < inMs + holdMs
            ? 0.0
            : -v.width * ((age - inMs - holdMs) / outMs));
    final h = cfg.number('bandH');
    final top = kFieldBottom / 2 - h / 2;
    final band = parseArgb(cfg.str('bandColor'), 'cutIn.bandColor');
    _rect(c, x, top, v.width + 1, h, ((cfg.number('bandAlpha') * 0xFF).round() << 24) | (band & 0xFFFFFF));
    final line = parseArgb(cfg.str('lineColor'), 'cutIn.lineColor');
    _rect(c, x, top, v.width + 1, 1, line);
    _rect(c, x, top + h - 1, v.width + 1, 1, line);
    final kind = cut.kind!;
    final scale = cfg.number('bossScale');
    final cx = x + v.width / 2;
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
    final v = scene.layout.viewDots;
    final (l, t, w, h) = (v.left, v.top, v.width + 1, scene.layout.bandTop - v.top);
    if (scene.bossFailMs > 0) {
      final a = (fx.bossFailed.number('alpha') * 0xFF).round();
      _rect(c, l, t, w, h, a << 24);
    }
    if (scene.bossWarnMs > 0) {
      final e = fx.bossEntrance;
      final period = e.number('ms') / (e.integer('blinks') * 2);
      final on = ((e.number('ms') - scene.bossWarnMs) / period).floor().isEven;
      if (!on) return;
      final px = e.number('borderPx');
      final color = _warnColor ??= parseArgb(e.str('color'), 'bossEntrance.color');
      _rect(c, l, t, w, px, color);
      _rect(c, l, t + h - px, w, px, color);
      _rect(c, l, t, px, h, color);
      _rect(c, l + w - 1 - px, t, px, h, color);
    }
  }

  int? _warnColor;
}

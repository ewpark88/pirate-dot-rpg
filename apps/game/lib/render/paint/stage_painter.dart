import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';
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
  final _hd = HdKit();

  void _rect(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l, t, w, h), _paint);
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
    // HD 카툰 보스면 종 그림을 띠 안에 바로 그린다(띠 높이의 1.6배 칸, 위아래는 띠 밖으로 조금 나가도 됨).
    final hd = hdBosses[kind];
    if (hd != null) {
      final cell = h * 1.6;
      final r = cell / (2 * hd.extent);
      c
        ..save()
        ..translate(cx, top + h / 2);
      _hd.begin(r);
      hd.draw(_hd, c, r, age % HdKit.loopMs);
      c.restore();
      return;
    }
    final sheet = sprites.sheet('boss:$kind');
    if (sheet != null) {
      // 큰 그림(대보스 88도트)은 띠 높이의 1.6배(기존 보스 최대 64)까지만.
      final k = math.min(scale / 2, h * 1.6 / sheet.frameH);
      sprites.draw(c, 'boss:$kind', cx, top + h / 2, w: sheet.frameW * k, h: sheet.frameH * k);
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

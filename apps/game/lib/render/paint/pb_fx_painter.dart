import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';

import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/paint/hook_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/paint/trail_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/motion.dart';

/// Pirate Busters 그림으로 그리는 발사체·폭발 (사용자 지시 '폭탄 퀄리티', fx_map `pbFx`).
/// - 발사체: 선원별 무기 그림(`weapon:<crewId>`). 투척·물수제비·낙하는 돌며 날고, 직선은 진행 방향을 보며 꼬리 잔상.
/// - 폭발: `explosion_aoe` 이펙트 하나를 단계로 — 번쩍 → 별 폭발·충격파 → 불덩이 5단계(뜨거움→연기) → 연기 덩이 퍼짐 → 물보라(바다면),
///   파편·불티는 포물선. 모양은 이펙트 위치로 정한 해시라 다시 재생해도 같다.
/// 그림이 없으면 false → 기존 도트 그림으로 그린다.
class PbFxPainter {
  PbFxPainter(this.scene, this.sprites);

  final BattleScene scene;
  final SpriteDraw sprites;

  late final JsonReader _cfg = scene.fx.raw.obj('pbFx');
  late final _trails = TrailPainter(scene);

  /// 전장 1단위의 dp (탑다운이면 TopFrame.dot — ScenePainter.paintTop이 넣고, 옆모습이면 null = 옆모습 배치).
  double? unitDp;
  double get _unitDp => unitDp ?? scene.layout.dot;
  static const _topMax = 12.0;
  late final _hooks = HookPainter(sprites);
  late final double _weaponDp = _cfg.number('weaponDp');
  late final double _weaponMinDots = _cfg.number('weaponMinDots');
  late final JsonReader _weaponContent = _cfg.obj('weaponContent');
  late final double _spinTurns = _cfg.number('spinTurns');
  late final double _trail = _cfg.number('trailStep');
  late final double _blastSize = _cfg.number('blastSize');
  late final double _waterY = _cfg.number('waterY');

  /// 가벼운 폭발(절전이거나 폭발이 많을 때): 연기·파편·불씨를 빼고 번쩍·불덩이·충격파만(S1 배터리). ScenePainter가 프레임마다 넣는다.
  bool lite = false;

  bool get blastReady => sprites.sheet('blast:fireball_0_hot') != null;

  /// 발사체 한 개. 무기 그림이 없으면 false.
  bool projectile(Canvas c, Projectile p) {
    final key = 'weapon:${p.crewId}';
    final sheet = sprites.sheet(key);
    if (sheet == null) return _hooks.paint(c, p, math.max(_weaponDp / _unitDp, _weaponMinDots));
    // 사용자 지시 '폭탄 그림이 보이게': 그림 '내용'(투명 여백 뺀 긴 변)이 화면 weaponDp dp(전장이 큰 태블릿은 최소 weaponMinDots 도트).
    final content = _weaponContent.has(p.crewId) ? _weaponContent.number(p.crewId) : sheet.frameW / 2;
    // 탑다운(사용자 '큰 검은 원이 거슬린다'): 배 폭의 1/4(약 12단위) 넘지 않게. 높이에 따른 +45%도 이 안에서.
    final size = unitDp == null
        ? math.max(_weaponDp / _unitDp, _weaponMinDots)
        : math.min(_weaponDp / _unitDp, _topMax / 1.45);
    final w = sheet.frameW * size / content;
    final h = sheet.frameH * size / content;
    if (p.flat) return _flat(c, p, key, size, w, h);
    _trails.paint(c, p, size);
    final spins = p.style.path != ProjectilePath.line;
    if (spins) {
      final turn = p.progress * _spinTurns * 2 * math.pi * (p.toX >= p.fromX ? 1 : -1);
      sprites.drawSmooth(c, key, p.x, p.y, w, h, angle: turn);
      return true;
    }
    final angle = math.atan2(p.toY - p.fromY, p.toX - p.fromX);
    for (var i = 3; i >= 1; i--) {
      final t = p.progress - i * _trail;
      if (t <= 0) continue;
      final (x, y) = positionAt(p, t);
      sprites.drawSmooth(c, key, x, y, w, h, angle: angle, alpha: 0.42 - i * 0.12);
    }
    sprites.drawSmooth(c, key, p.x, p.y, w, h, angle: angle);
    return true;
  }

  final _shadow = Paint()..color = const Color(0x401B1726);

  /// 탑다운: 수면 그림자(높을수록 작고 흐림) + 높이만큼 위로·크게 그린 무기. 회전은 옆모습과 같게.
  bool _flat(Canvas c, Projectile p, String key, double size, double w, double h) {
    final height = heightAt(p, p.progress);
    final lift = height / (p.style.arcPx <= 0 ? 1 : p.style.arcPx);
    c.drawOval(
      Rect.fromCenter(center: Offset(p.x, p.y), width: size * (0.7 - 0.25 * lift), height: size * (0.35 - 0.12 * lift)),
      _shadow,
    );
    final grow = 1 + 0.45 * lift;
    final turn = p.progress * _spinTurns * 2 * math.pi;
    final angle = p.style.path == ProjectilePath.line ? math.atan2(p.toY - p.fromY, p.toX - p.fromX) : turn;
    sprites.drawSmooth(c, key, p.x, p.y - height * 0.35, w * grow, h * grow, angle: angle);
    return true;
  }

  /// 폭발 한 개(이펙트 나이로 단계). 부품 그림이 없으면 false.
  bool blast(Canvas c, Effect e) {
    if (!blastReady) return false;
    final t = e.ageMs - e.delayMs;
    final d = e.w * _blastSize;
    final seed = ((e.x * 7.0).round() * 31 + (e.y * 3.0).round()) & 0x7fffffff;
    void part(
      String name,
      double from,
      double to,
      double Function(double u) size,
      double Function(double u) alpha, {
      double dx = 0,
      double dy = 0,
      double angle = 0,
      double aspect = 1,
    }) {
      if (t < from || t > to) return;
      final u = (t - from) / (to - from);
      final s = size(u);
      sprites.drawSmooth(
        c,
        'blast:$name',
        e.x + dx,
        e.y + dy,
        s,
        s * aspect,
        angle: angle,
        alpha: alpha(u).clamp(0, 1),
      );
    }

    part('shockwave', 50, 330, (u) => d * (0.6 + 1.0 * u), (u) => 0.8 * (1 - u), aspect: 224 / 272);
    if (e.y >= _waterY) {
      part(
        'splash_small',
        120,
        560,
        (u) => d * (0.6 + 0.4 * u),
        (u) => u < 0.7 ? 1 : (1 - u) / 0.3,
        dy: d * 0.12,
        aspect: 72 / 104,
      );
    }
    for (var i = 0; i < (lite ? 0 : 3); i++) {
      final a = (seed % 360 + i * 120) * math.pi / 180;
      final from = 180.0 + i * 50;
      part(
        i == 0 ? 'puff_3' : 'puff_6',
        from,
        from + 650,
        (u) => d * (0.28 + 0.3 * u),
        (u) => 0.85 * (1 - u),
        dx: math.cos(a) * d * 0.28,
        dy: math.sin(a) * d * 0.18 - d * 0.25 * ((t - from) / 650).clamp(0, 1),
      );
    }
    if (t >= 60 && t < 560) {
      final u = (t - 60) / 500;
      const frames = [
        'fireball_0_hot',
        'fireball_1_fire',
        'fireball_2_cool',
        'fireball_3_smoke_hot',
        'fireball_4_smoke',
      ];
      final f = frames[(u * frames.length).floor().clamp(0, frames.length - 1)];
      final s = d * (0.55 + 0.35 * u);
      sprites.drawSmooth(c, 'blast:$f', e.x, e.y - d * 0.08 * u, s, s, alpha: u > 0.8 ? (1 - u) / 0.2 : 1);
    }
    part(
      'burst',
      0,
      220,
      (u) => d * (0.55 + 0.45 * math.min(1, u * 2)),
      (u) => u < 0.6 ? 1 : (1 - u) / 0.4,
      angle: (seed % 7) * 0.12,
    );
    part('flash', 0, 90, (u) => d * (0.5 + 0.7 * u), (u) => 1 - u);
    for (var i = 0; i < (lite ? 0 : 4); i++) {
      final a = -math.pi * (0.15 + 0.7 * ((seed >> (i * 3)) % 8) / 7);
      final v = d * (1.1 + 0.4 * ((seed >> (i * 2)) % 4) / 3);
      final g = d * 3.2;
      final sec = t / 1000;
      if (t > 700) break;
      sprites.drawSmooth(
        c,
        i == 3 ? 'blast:debris_plank' : 'blast:debris_${i % 3}',
        e.x + math.cos(a) * v * sec,
        e.y + math.sin(a) * v * sec + g * sec * sec,
        d * 0.13,
        d * 0.13,
        angle: sec * 9 * (i.isEven ? 1 : -1),
        alpha: t > 550 ? (700 - t) / 150 : 1,
      );
    }
    for (var i = 0; i < (lite ? 0 : 6); i++) {
      final a = -math.pi * (0.1 + 0.8 * i / 5);
      final v = d * 1.6;
      final sec = t / 1000;
      if (t > 600) break;
      sprites.drawSmooth(
        c,
        'blast:ember',
        e.x + math.cos(a) * v * sec,
        e.y + math.sin(a) * v * sec + d * 2.5 * sec * sec,
        d * 0.05,
        d * 0.05,
        alpha: 1 - t / 600,
      );
    }
    return true;
  }
}

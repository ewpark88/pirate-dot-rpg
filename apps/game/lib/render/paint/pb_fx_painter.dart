import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';

import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/paint/hook_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/paint/trail_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/motion.dart';
import 'package:pirate_dot/render/top/top_shot_body.dart';

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
  static const _topBlastMax = 30.0;
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

  /// 피버 세기 0~1 (탑다운): 발사체를 굵게 + 불 꼬리. ScenePainter가 프레임마다 넣는다.
  double fever = 0;

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
    // 타격감 v3: 폭탄 15% 크게 + 착탄 직전(마지막 15%) 원근으로 15% 더 커짐.
    final near = p.progress > 0.85 ? (p.progress - 0.85) / 0.15 : 0.0;
    final grow = (1 + 0.45 * lift) * (1 + 0.35 * fever) * 1.15 * (1 + 0.15 * near);
    // 등급 꼬리(영웅·전설·신화) 먼저, 피버면 불 꼬리를 더한다(S1). 붐빔(lite)이면 꼬리 생략(부하, S1 발사체 v2).
    final crowd = scene.topHits.lite;
    if (!crowd) _trails.paint(c, p, size);
    if (fever > 0 && !crowd) _fireTail(c, p, size, height);
    final turn = p.progress * _spinTurns * 2 * math.pi;
    final heading = math.atan2(p.toY - p.fromY, p.toX - p.fromX);
    final angle = p.style.path == ProjectilePath.line ? heading : turn;
    if (TopShotBody.has(p.family)) {
      // 발사체 몸통 HD v2(S1): 계열별 벡터 몸통, 등급이 높을수록 크고 빛 무리. 곡사(포탄·집속)는 연기 꼬리.
      final rarity = _trails.rarityOf(p.crewId);
      final at = Offset(p.x, p.y - height * 0.35);
      if (!crowd && (p.family == 'lob' || p.family == 'cluster')) _smoke(c, p, size);
      _body.paint(
        c,
        p.family,
        at,
        size * grow * 0.5 * TopShotBody.scaleOf(rarity),
        heading,
        turn * (p.toX >= p.fromX ? 1 : -1),
        p.progress,
        scene.clockMs,
        rarity,
        lite: crowd || scene.settings.powerSave,
      );
      return true;
    }
    // 굵은 윤곽: 폭탄 뒤 진한 그림자 원(바다·폭발 위에서도 형태가 읽히게).
    _fire.color = const Color(0x881E1A26);
    c.drawCircle(Offset(p.x, p.y - height * 0.35), size * grow * 0.5, _fire);
    sprites.drawSmooth(c, key, p.x, p.y - height * 0.35, w * grow, h * grow, angle: angle);
    return true;
  }

  final _fire = Paint()..isAntiAlias = false;
  final _body = TopShotBody();

  /// 곡사 연기 꼬리: 지나온 자리에 회색 연기 셋이 커지며 옅어진다.
  void _smoke(Canvas c, Projectile p, double size) {
    for (var k = 1; k <= 3; k++) {
      final t = p.progress - k * 0.06;
      if (t <= 0) continue;
      final (x, gy) = positionAt(p, t);
      _fire.color = Color.fromRGBO(230, 230, 236, 0.5 - k * 0.13);
      c.drawCircle(Offset(x, gy - heightAt(p, t) * 0.35), size * (0.25 + 0.12 * k), _fire);
    }
  }

  /// 피버 불 꼬리: 날아온 쪽으로 주황·노랑 불덩이 4개가 작아지며 흐려진다.
  void _fireTail(Canvas c, Projectile p, double size, double height) {
    final dx = p.toX - p.fromX;
    final dy = p.toY - p.fromY;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-6) return;
    final ux = dx / len;
    final uy = dy / len;
    for (var i = 4; i >= 1; i--) {
      final back = i * size * 0.45;
      final r = size * (0.55 - i * 0.09);
      _fire.color = (i.isEven ? const Color(0xFFFF8A2A) : const Color(0xFFFFD84A)).withValues(
        alpha: fever * (0.9 - i * 0.17),
      );
      c.drawCircle(Offset(p.x - ux * back, p.y - uy * back - height * 0.35), r, _fire);
    }
  }

  /// 폭발 한 개(이펙트 나이로 단계). 부품 그림이 없으면 false.
  bool blast(Canvas c, Effect e) {
    if (!blastReady) return false;
    final t = e.ageMs - e.delayMs;
    // 탑다운: 범위가 넓은 공격(S2 topRadius 34 등)이어도 폭발 그림은 배 길이의 반 정도까지만(배를 덮지 않게).
    final d = unitDp == null ? e.w * _blastSize : math.min(e.w * _blastSize, _topBlastMax);
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
    // 흰 번쩍 층(flash)은 뺐다 — 사용자 '흰 번쩍임이 너무 많아 눈이 아프다'.
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

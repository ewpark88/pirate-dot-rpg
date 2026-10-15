import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/hud_painter.dart';
import 'package:pirate_dot/render/paint/pb_fx_painter.dart';
import 'package:pirate_dot/render/paint/ship_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/paint/stage_painter.dart';
import 'package:pirate_dot/render/paint/status_painter.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

/// [BattleScene]을 캔버스에 그린다. 스프라이트([sprites])가 있으면 그것으로, 없으면 단색 플레이스홀더.
/// Flame 컴포넌트와 골든 테스트가 같이 쓴다.
///
/// 그리는 순서: 배경 → 물속 적 → 배 → 물위 적 → 공중 적 → 발사체 → 이펙트 → 코인 → 숫자 → (흔들림 밖) 슬롯·플래시.
class ScenePainter {
  ScenePainter(this.scene) : _status = StatusPainter(scene) {
    _hud = HudPainter(scene, _sprite);
    _ship = ShipPainter(scene, _sprite);
    _pb = PbFxPainter(scene, _sprite);
    _stage = StagePainter(scene, _sprite);
    _sprite.slowed = ColorFilter.mode(Color(_status.slowedTint), BlendMode.srcATop);
  }

  final BattleScene scene;
  late final StagePainter _stage;
  final StatusPainter _status;
  final _sprite = SpriteDraw();
  late final HudPainter _hud;
  late final ShipPainter _ship;
  late final PbFxPainter _pb;

  /// 아트 팩 이미지. null이거나 키가 없으면 플레이스홀더.
  SpriteBank? get sprites => _sprite.bank;
  set sprites(SpriteBank? v) => _sprite.bank = v;

  /// 운영자 "스프라이트 끄기".
  bool get useSprites => _sprite.enabled;
  set useSprites(bool v) => _sprite.enabled = v;

  late final double _animMs = scene.fx.sprites.number('animMs');
  int _animFrame(int salt) => (scene.clockMs / _animMs).floor() + salt;

  /// 운영자 모드: 적 히트박스 표시.
  bool showHitboxes = false;

  final _paint = Paint()..isAntiAlias = false;
  final _stroke = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static const _hpBack = Color(0xFF3A0D0D);
  static const _hpFront = Color(0xFF5BD75B);
  static const _hitbox = Color(0xFFFF00FF);
  static const _underwaterTint = Color(0xFF0B2A44);

  void paint(Canvas canvas) {
    canvas
      ..save()
      ..translate(scene.shake.offsetX, scene.shake.offsetY);
    _stage.paintBackground(canvas);
    _zones(canvas);
    _stage.paintChest(canvas);
    _sprite.underwaterAlpha = scene.backdrop.underwaterAlpha;
    _enemies(canvas, 'underwater');
    _ship.paint(canvas);
    _enemies(canvas, 'surface');
    _enemies(canvas, 'air');
    _projectiles(canvas);
    _effects(canvas);
    _coins(canvas);
    _hud.paintNumbers(canvas);
    canvas.restore();
    _stage.paintOverlays(canvas);
    _hud
      ..paintHud(canvas)
      ..paintSlots(canvas);
    if (scene.screenFlashMs > 0) {
      final v = scene.layout.viewDots;
      _fill(canvas, v.left, v.top, v.width + 1, scene.layout.bandTop - v.top, 0x99FFFFFF);
    }
  }

  void _fill(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l.roundToDouble(), t.roundToDouble(), w.roundToDouble(), h.roundToDouble()), _paint);
  }

  late final int _zoneColor =
      ((scene.fx.zone.number('alpha') * 0xFF).round() << 24) |
      (parseArgb(scene.fx.zone.str('color'), 'zone.color') & 0xFFFFFF);

  void _zones(Canvas c) {
    _paint.color = Color(_zoneColor);
    for (final z in scene.zones.active) {
      c.drawCircle(Offset(z.x.roundToDouble(), z.y.roundToDouble()), z.radius.roundToDouble(), _paint);
    }
  }

  /// 같은 층 안에서는 y 순서로(뒤 → 앞). 정렬 버퍼는 재사용한다.
  final List<int> _order = [];

  void _enemies(Canvas c, String layer) {
    _order.clear();
    for (var k = 0; k < scene.poseCount; k++) {
      final e = scene.poses[k];
      if (e.layer != layer || e.drawX > kLogicalWidth + kBossSize) continue;
      var i = _order.length;
      _order.add(k);
      while (i > 0 && scene.poses[_order[i - 1]].drawY > e.drawY) {
        _order[i] = _order[i - 1];
        i--;
      }
      _order[i] = k;
    }
    for (final k in _order) {
      _enemy(c, scene.poses[k]);
    }
  }

  static const _bobAmp = 1.2;
  static const _bobRate = 3.0;

  void _enemy(Canvas c, EnemyPose e) {
    final looks = scene.looks;
    final bossShape = looks.bossOf(e.kind, boss: e.boss);
    final key = bossShape != null ? 'boss:${e.kind}' : 'enemy:${e.kind}';
    final sheet = _sprite.sheet(key);
    final w = sheet?.frameW ?? bossShape?.w ?? looks.sizeOf(e.kind);
    final h = sheet?.frameH ?? bossShape?.h ?? w;
    // 발밑 기준(y = 발) + 출렁임 sin(t·3 + 위상)·1.2px (기준 장면).
    final bob = (math.sin(scene.clockMs / Duration.millisecondsPerSecond * _bobRate + e.id) * _bobAmp).roundToDouble();
    final l = e.drawX - w / 2;
    final t = e.drawY - h + bob;
    final under = e.layer == 'underwater';
    final alpha = bossShape == null ? looks.alphaOf(e.kind) : 1.0;
    if (!_sprite.draw(
      c,
      key,
      e.drawX,
      t + h / 2,
      frame: _animFrame(e.id),
      flash: e.flash,
      underwater: under,
      isSlowed: e.slowed,
      alpha: alpha,
    )) {
      var color = bossShape?.color ?? looks.colorOf(e.kind);
      if (under) color = Color.lerp(Color(color), _underwaterTint, scene.backdrop.underwaterAlpha)!.toARGB32();
      if (e.slowed) color = _status.tintColor(color);
      color = ((alpha * 0xFF).round() << 24) | (color & 0xFFFFFF);
      _fill(c, l, t, w, h, e.flash ? 0xFFFFFFFF : color);
    }
    if (bossShape != null) {
      _fill(c, l, t - 3, w, 1, _hpBack.toARGB32());
      _fill(c, l, t - 3, w * e.hpRatio, 1, _hpFront.toARGB32());
    }
    final tierColor = looks.tierColor(e.tier);
    if (tierColor != null) _outline(c, l, t, w, h, 1, 1, tierColor);
    if (e.shielded) _outline(c, l, t, w, h, _shieldGap, _shieldPx, _shieldColor);
    _status.paint(c, e, e.drawY - h, e.drawY);
    if (showHitboxes) {
      _stroke.color = _hitbox;
      c.drawRect(Rect.fromLTWH(l, t, w, h), _stroke);
    }
  }

  late final int _shieldColor = parseArgb(scene.fx.shield.str('color'), 'shield.color');
  late final double _shieldPx = scene.fx.shield.number('px');

  /// tier 테두리(1px) 바깥에 보호막이 오도록 띄우는 간격.
  static const _shieldGap = 3.0;

  /// 적 사각형 바깥 [gap]px에 [px] 두께 테두리.
  void _outline(Canvas c, double l, double t, double w, double h, double gap, double px, int color) {
    _stroke
      ..color = Color(color)
      ..strokeWidth = px;
    final o = gap - px / 2;
    c.drawRect(Rect.fromLTWH(l - o, t - o, w + o * 2, h + o * 2), _stroke);
    _stroke.strokeWidth = 1;
  }

  void _projectiles(Canvas c) {
    for (final p in scene.projectiles.active) {
      if (scene.player.position < p.startIndex) continue;
      if (_pb.projectile(c, p)) continue;
      if (_sprite.draw(c, 'projectile:${p.family}', p.x, p.y)) continue;
      final s = p.style.size;
      _fill(c, p.x - s / 2, p.y - s / 2, s, s, p.style.color);
    }
  }

  void _effects(Canvas c) {
    for (final e in scene.effects.active) {
      if (!e.visible) continue;
      if (e.sheetId == 'explosion_aoe' && _pb.blast(c, e)) continue;
      final cy = _bottomAnchored.contains(e.sheetId) ? e.y - e.h / 2 : e.y;
      if (_sprite.draw(c, 'fx:${e.sheetId}', e.x, cy, frame: e.frame, w: e.w, h: e.h)) continue;
      final t = e.frame / e.frames;
      final scale = 0.5 + 0.5 * t;
      final alpha = ((1 - t) * 0xCC).round() << 24;
      final w = e.w * scale;
      final h = e.h * scale;
      _stroke
        ..color = Color(alpha | (e.color & 0xFFFFFF))
        ..strokeWidth = 2;
      c.drawRect(
        Rect.fromLTWH(
          (e.x - w / 2).roundToDouble(),
          (e.y - h / 2).roundToDouble(),
          w.roundToDouble(),
          h.roundToDouble(),
        ),
        _stroke,
      );
      _stroke.strokeWidth = 1;
    }
  }

  /// 코인 반짝임 3프레임을 초당 12장 (기준 장면).
  static const _coinFps = 12;

  late final Set<String> _bottomAnchored = {
    for (final e in scene.fx.sheetAnchors.raw.entries)
      if (e.value == 'bottom') e.key,
  };

  void _coins(Canvas c) {
    for (final coin in scene.coins.active) {
      if (coin.ageMs < 0) continue;
      if (_sprite.draw(c, 'coin', coin.x, coin.y, frame: (coin.ageMs * _coinFps / 1000).floor())) continue;
      _fill(c, coin.x - 1, coin.y - 1, 2, 2, 0xFFFFD23F);
    }
  }
}

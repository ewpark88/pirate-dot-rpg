import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/ship_hp_painter.dart';
import 'package:pirate_dot/render/paint/ship_parts_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/ship_geometry.dart';

/// 내 배: 등급별 그림(`ship:<tierId>` 스프라이트, 없으면 플레이스홀더), HP 바, 배 스킬 번쩍임·버프 테두리, 승급 빛기둥.
class ShipPainter {
  ShipPainter(this.scene, this.sprites);

  final BattleScene scene;
  final SpriteDraw sprites;

  late final _parts = ShipPartsPainter(scene, sprites);
  late final _hp = ShipHpPainter(scene);
  final _paint = Paint()..isAntiAlias = false;
  final _stroke = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  static const _hull = 0xFF8B5A2B;
  static const _deck = 0xFFC49A6C;
  static const _white = 0xFFFFFFFF;
  static const _pillarAlpha = 0.6;
  static const _pulseMs = 60.0;

  late final int _heal = parseArgb(scene.fx.shipSkill.str('healColor'), 'shipSkill.healColor');
  late final int _buff = parseArgb(scene.fx.shipSkill.str('buffColor'), 'shipSkill.buffColor');
  late final int _pillarColor = parseArgb(scene.fx.pillar.str('color'), 'pillar.color');

  void _fill(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l.roundToDouble(), t.roundToDouble(), w.roundToDouble(), h.roundToDouble()), _paint);
  }

  void paint(Canvas c) {
    final flash = scene.shipFlashMs > 0 && scene.settings.flash;
    final tier = scene.moments.shipTierId;
    final bob = scene.shipBob;
    c
      ..save()
      ..translate(0, bob);
    _sink(c);
    // 등급 그림 + 부품 외형 단계 덧그림 + 뱃머리 대포 (ShipGeometry: 뱃머리·포구 높이 기준 shipScale배).
    final sheet = sprites.sheet('ship:$tier');
    final box = sheet == null
        ? const Rect.fromLTWH(kShipLeft, kShipTop, kShipWidth, kShipHeight)
        : ShipGeometry.box(scene, sheet.frameW, sheet.frameH);
    if (!sprites.draw(c, 'ship:$tier', box.center.dx, box.center.dy, w: box.width, h: box.height, flash: flash)) {
      _placeholder(c, tier, flash);
    } else {
      _parts.paint(c, tier, box, sheet!.frameW, flash: flash);
    }
    if (scene.moments.sinkMs <= 0) _hp.paint(c, box);
    c.restore();
    if (scene.shipHealMs > 0 && scene.settings.flash) {
      _fill(c, box.left, box.top, box.width, box.height, (0x88 << 24) | (_heal & 0xFFFFFF));
    }
    if (scene.shipBuffMs > 0) {
      _stroke.color = Color(_buff);
      c.drawRect(box, _stroke);
    }
    _pillar(c);
  }

  /// 1단계는 처음 플레이스홀더 그대로, 그 위 등급은 `fx_map.shipLook[tierId]` 색·크기(앞머리 x=56, 물 위에 맞춤).
  void _placeholder(Canvas c, String tier, bool flash) {
    final look = scene.fx.shipLook.has(tier) ? scene.fx.shipLook.obj(tier) : null;
    if (look == null) {
      _fill(c, kShipLeft, kShipTop + kShipHeight / 2, kShipWidth, kShipHeight / 2, flash ? _white : _hull);
      _fill(c, kShipLeft + 8, kShipTop, 4, kShipHeight / 2, flash ? _white : _deck);
      _fill(c, kShipLeft + 28, kShipTop + 4, 18, 14, flash ? _white : _deck);
      return;
    }
    final w = look.number('w');
    final h = look.number('h');
    final color = flash ? _white : parseArgb(look.str('color'), '${look.path}.color');
    const bottom = kShipTop + kShipHeight;
    _fill(c, kShipNoseX - w, bottom - h / 2, w, h / 2, color);
    _fill(c, kShipNoseX - w + 8, bottom - h, 4, h / 2, flash ? _white : _deck);
    _fill(c, kShipNoseX - w / 2, bottom - h + 4, w / 3, h / 3, flash ? _white : _deck);
  }

  /// 무리전 침몰: 앞 절반 뱃머리를 들며 기울어 가라앉고, 뒤 절반 고쳐져 똑바로 떠오른다(moments.sinkMs).
  void _sink(Canvas c) {
    final left = scene.moments.sinkMs;
    if (left <= 0) return;
    final cfg = scene.fx.raw.obj('shipHp');
    final p = 1 - left / cfg.number('sinkMs');
    final down = p < 0.5 ? p / 0.5 : 1 - (p - 0.5) / 0.5;
    final tilt = p < 0.5 ? cfg.number('sinkTilt') * p / 0.5 : 0.0;
    final v = scene.layout.viewDots;
    c
      ..clipRect(Rect.fromLTRB(v.left, v.top, v.right, ShipGeometry.waterline(scene)))
      ..translate(kShipCenterX, kShipTop + kShipHeight)
      ..rotate(-tilt)
      ..translate(-kShipCenterX, -(kShipTop + kShipHeight) + cfg.number('sinkDepth') * down);
  }

  void _pillar(Canvas c) {
    final left = scene.moments.pillarMs;
    if (left <= 0) return;
    final p = scene.fx.pillar;
    final fade = left / p.number('ms');
    final pulse = 0.75 + 0.25 * math.sin(scene.clockMs / _pulseMs);
    final a = (_pillarAlpha * fade * pulse * 0xFF).round().clamp(0, 0xFF);
    final w = p.number('w');
    _fill(c, kShipCenterX - w / 2, 0, w, kShipTop + kShipHeight, (a << 24) | (_pillarColor & 0xFFFFFF));
  }
}

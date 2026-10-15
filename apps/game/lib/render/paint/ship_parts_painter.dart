import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/ship_geometry.dart';

/// 배 부품 외형 단계 (사용자 지시 '업그레이드 때 디자인이 바뀌게', S2 BattleView.shipLook): 등급 배 위에 부위별 덧그림
/// (`ship_part:<tierId>:<part>` 프레임 = 단계−1, 0단계는 1단계 그림) + 뱃머리 대포 레이어(`ship_cannon`, 발사 때 반동).
/// ShipLookChanged면 그 부위가 흰빛으로 맥박친다(moments.glowPart).
class ShipPartsPainter {
  ShipPartsPainter(this.scene, this.sprites);

  final BattleScene scene;
  final SpriteDraw sprites;
  late final JsonReader _cfg = scene.fx.raw.obj('shipParts');
  late final List<String> _parts = [for (final k in _cfg.obj('stages').raw.keys) k];
  late final double _recoilMs = _cfg.number('recoilMs');
  late final double _recoilPx = _cfg.number('recoilPx');
  late final double _glowMs = _cfg.number('glowMs');
  late final double _cannonScale = _cfg.number('cannonScale');

  int _frame(String part, int frames) {
    final stage = scene.frame.shipLook[part] ?? 0;
    return (math.max(stage, 1) - 1).clamp(0, frames - 1);
  }

  /// [box] = 배 그림 상자 (도트), [frameW] = 배 그림 폭 (그림 픽셀).
  void paint(Canvas c, String tier, Rect box, double frameW, {required bool flash}) {
    final m = scene.moments;
    final pulse = m.glowMs > 0 ? 0.5 + 0.5 * math.sin((1 - m.glowMs / _glowMs) * math.pi * 6) : 0.0;
    for (final part in _parts) {
      final key = 'ship_part:$tier:$part';
      final sheet = sprites.sheet(key);
      if (sheet == null) continue;
      final f = _frame(part, sheet.frames);
      sprites.draw(c, key, box.center.dx, box.center.dy, frame: f, w: box.width, h: box.height, flash: flash);
      if (m.glowMs > 0 && m.glowPart == part) {
        sprites.draw(
          c,
          key,
          box.center.dx,
          box.center.dy,
          frame: f,
          w: box.width,
          h: box.height,
          flash: true,
          alpha: pulse,
        );
      }
    }
    _cannon(c, box.width / frameW, flash: flash || (m.glowMs > 0 && m.glowPart == 'cannon' && pulse > 0.5));
  }

  void _cannon(Canvas c, double s, {required bool flash}) {
    final sheet = sprites.sheet('ship_cannon');
    if (sheet == null) return;
    final since = scene.clockMs - scene.moments.cannonFiredAtMs;
    final kick = since >= 0 && since < _recoilMs ? -_recoilPx * s * (1 - since / _recoilMs) : 0.0;
    // 대포는 배보다 cannonScale배 크게(사용자 지시 '대포가 잘 보이게') — 포구 끝(발사 위치) 기준으로 키운다.
    final cs = s * _cannonScale;
    final w = ShipGeometry.cannonW * cs;
    final h = ShipGeometry.cannonH * cs;
    final tip = ShipGeometry.cannonTip(scene);
    final left = tip.dx - w + kick;
    final top = tip.dy - ShipGeometry.cannonTipRow * cs;
    sprites.draw(
      c,
      'ship_cannon',
      left + w / 2,
      top + h / 2,
      frame: _frame('cannon', sheet.frames),
      w: w,
      h: h,
      flash: flash,
    );
  }
}

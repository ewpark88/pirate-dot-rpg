import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/ship_hp_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/render/top/top_sea_painter.dart';
import 'package:pirate_dot/render/top/top_ship_painter.dart';

/// 탑다운 장면 (T2): 배 가운데 고정 카메라 → 바다(흐름) → 항적 → 물속 적 → 배(그림자·층·체력 막대) → 물 위·공중 적 → fx
/// fx(발사체·폭발·코인·숫자 — 옆모습과 같은 그리기, 전장 좌표). 상자 dp 좌표 캔버스에 그린다.
/// 배 화면 자리는 보이는 전장 가운데 — 시트를 열어 보이는 전장이 줄면 [_followMs]에 걸쳐 따라간다(k는 폭으로만 정해 그대로).
class TopScenePainter {
  TopScenePainter(this.scene, this.sprites);

  final BattleScene scene;
  final SpriteDraw sprites;
  late final TopSeaPainter _sea = TopSeaPainter(scene.fx.raw.obj('topSea'));
  late final TopShipPainter _ship = TopShipPainter(sprites);
  late final ShipHpPainter _hp = ShipHpPainter(scene);

  double? _shipY;
  double _lastMs = 0;
  static const _followMs = 220.0;
  static const _underwaterAlpha = 0.55;

  void paint(Canvas c, TopFrame frame, void Function(Canvas c) fx) {
    final clockMs = scene.clockMs;
    final dt = (clockMs - _lastMs).clamp(0.0, 100.0);
    _lastMs = clockMs;
    final target = frame.shipScreen.dy;
    final y = _shipY ?? target;
    _shipY = y + (target - y) * math.min(1, dt / _followMs * 3);
    final dpr = frame.dpr;
    final sx = (frame.shipScreen.dx * dpr).roundToDouble() / dpr;
    final sy = (_shipY! * dpr).roundToDouble() / dpr;
    final dot = frame.dot;
    final view = scene.frame;
    final ship = scene.topShip;
    final tier = scene.moments.shipTierId;
    c
      ..save()
      ..clipRect(Offset.zero & frame.box)
      ..translate(sx + scene.shake.offsetX * dot, sy + scene.shake.offsetY * dot)
      ..scale(dot);
    final viewRect = Rect.fromLTWH(-sx / dot, -sy / dot, frame.box.width / dot, frame.box.height / dot);
    _sea
      ..advance(clockMs, view.shipHeading)
      ..paint(c, viewRect, clockMs);
    // 전장 좌표로: 배 중심이 원점.
    c
      ..save()
      ..translate(-ship.dx, -ship.dy);
    _enemies(c, under: true);
    c.restore();
    final size = _ship.sizeOf(tier);
    if (size != null) {
      final m = scene.moments;
      c
        ..save()
        ..rotate(view.shipHeading);
      _sea.wake(c, size.height / 2 - 4, size.height / 2, size.width / 2 * 0.6, clockMs);
      _ship.paint(
        c,
        tier,
        view.shipLook,
        flash: scene.shipFlashMs > 0 && scene.settings.flash,
        glowPart: m.glowMs > 0 ? m.glowPart : null,
        glow: m.glowMs > 0 ? 0.5 + 0.5 * math.sin(clockMs / 70) : 0,
      );
      c.restore();
      _hp.paint(c, Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height));
    }
    c
      ..save()
      ..translate(-ship.dx, -ship.dy);
    _enemies(c, under: false);
    fx(c);
    c
      ..restore()
      ..restore();
  }

  void _enemies(Canvas c, {required bool under}) {
    for (final e in scene.poses) {
      if ((e.layer == 'underwater') != under) continue;
      _enemy(c, e, alpha: under ? _underwaterAlpha : 1);
    }
  }

  void _enemy(Canvas c, EnemyPose e, {double alpha = 1}) {
    final key = e.boss ? 'td_boss:${e.kind}' : 'td_enemy:${e.kind}';
    final sheet = sprites.sheet(key);
    if (sheet == null) return;
    final frame = ((scene.clockMs / 220).floor() + e.id) % sheet.frames;
    c
      ..save()
      ..translate(e.drawX.roundToDouble(), e.drawY.roundToDouble())
      ..rotate(e.heading + math.pi / 2);
    sprites.draw(c, key, 0, 0, frame: frame, flash: e.flash, alpha: alpha);
    c.restore();
  }
}

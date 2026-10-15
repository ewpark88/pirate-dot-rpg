import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/ship_hp_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_atmosphere.dart';
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
  late final TopAtmosphere atmosphere = TopAtmosphere(scene.fx.raw.obj('atmosphere'), sprites);

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
    final powerSave = scene.settings.powerSave;
    atmosphere
      ..update(clockMs, scene.tables.regions.regionAt(view.stage).id, _sea.flow, view.shipHeading, powerSave: powerSave)
      ..paintUnder(c, viewRect, clockMs, powerSave: powerSave);
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
      final sinking = _sink(c, m.sinkMs);
      _ship.paint(
        c,
        tier,
        view.shipLook,
        flash: scene.shipFlashMs > 0 && scene.settings.flash,
        glowPart: m.glowMs > 0 ? m.glowPart : null,
        glow: m.glowMs > 0 ? 0.5 + 0.5 * math.sin(clockMs / 70) : 0,
        recoil: _recoil(clockMs - m.cannonFiredAtMs),
      );
      if (sinking) c.restore();
      c.restore();
      if (m.sinkMs <= 0) _hp.paint(c, Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height));
    }
    c
      ..save()
      ..translate(-ship.dx, -ship.dy);
    _enemies(c, under: false);
    fx(c);
    c.restore();
    atmosphere.paintOver(c, viewRect, clockMs, powerSave: scene.settings.powerSave);
    c.restore();
  }

  late final double _recoilMs = scene.fx.raw.obj('shipParts').number('recoilMs');

  /// 발사 뒤 [since] ms의 반동 0~1 (발사 순간 1 → recoilMs에 0).
  double _recoil(double since) => since >= 0 && since < _recoilMs ? 1 - since / _recoilMs : 0;

  /// 탑다운 침몰(무리전 HP 0): 앞 절반 작아지며 물에 잠기고(어두워짐) 거품, 뒤 절반 원래 크기로 떠오름. 레이어를 열었으면 true.
  bool _sink(Canvas c, double left) {
    if (left <= 0) return false;
    final p = 1 - left / scene.fx.raw.obj('shipHp').number('sinkMs');
    final down = p < 0.5 ? p / 0.5 : 1 - (p - 0.5) / 0.5;
    _bubble.color = const Color(0xCCF2FBFF);
    for (var i = 0; i < 8; i++) {
      final a = i * 0.785 + scene.clockMs / 400;
      c.drawCircle(Offset(math.cos(a) * 26 * down, math.sin(a) * 40 * down), 1 + (i % 3) * down, _bubble);
    }
    final s = 1 - 0.35 * down;
    _sinkPaint.color = Color.fromRGBO(255, 255, 255, 1 - 0.6 * down);
    c
      ..saveLayer(null, _sinkPaint)
      ..scale(s);
    return true;
  }

  final _bubble = Paint();
  final _sinkPaint = Paint();

  /// 적을 그림(종류)별로 묶어 drawAtlas 한 번씩 — 150마리여도 그리기 몇 번(S1 부하: 100~150마리 60fps).
  /// 맞은 적(흰 번쩍임)은 흰 실루엣 묶음으로 따로, 물속은 반투명 붓으로.
  void _enemies(Canvas c, {required bool under}) {
    for (final b in _batches.values.followedBy(_flashBatches.values)) {
      b.clear();
    }
    for (final e in scene.poses) {
      if ((e.layer == 'underwater') != under) continue;
      final key = (e.boss ? _bossKeys : _enemyKeys)[e.kind] ??= e.boss ? 'td_boss:${e.kind}' : 'td_enemy:${e.kind}';
      final sheet = sprites.sheet(key);
      if (sheet == null) continue;
      final frame = ((scene.clockMs / 220).floor() + e.id) % sheet.frames;
      (e.flash ? _flashBatches : _batches).putIfAbsent(sheet, () => _Batch(sheet.image, flash: e.flash))
        ..xf.add(
          RSTransform.fromComponents(
            rotation: e.heading + math.pi / 2,
            scale: 1,
            anchorX: sheet.frameW / 2,
            anchorY: sheet.frameH / 2,
            translateX: e.drawX.roundToDouble(),
            translateY: e.drawY.roundToDouble(),
          ),
        )
        ..src.add(Rect.fromLTWH(frame * sheet.frameW, 0, sheet.frameW, sheet.frameH));
    }
    for (final b in _batches.values.followedBy(_flashBatches.values)) {
      if (b.xf.isEmpty) continue;
      final paint = b.flash ? _flashPaint : (under ? _underPaint : _atlasPaint);
      c.drawAtlas(b.image, b.xf, b.src, null, null, null, paint);
    }
  }

  final Map<SpriteSheet, _Batch> _batches = {};
  final Map<SpriteSheet, _Batch> _flashBatches = {};
  final Map<String, String> _enemyKeys = {};
  final Map<String, String> _bossKeys = {};
  final _atlasPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  late final _underPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..color = const Color.fromRGBO(255, 255, 255, _underwaterAlpha);
  final _flashPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn);
}

/// 같은 그림(종류·번쩍임) 적 묶음 — 프레임마다 비우고 다시 채운다(리스트 재사용).
class _Batch {
  _Batch(this.image, {required this.flash});
  final Image image;
  final bool flash;
  final xf = <RSTransform>[];
  final src = <Rect>[];

  void clear() {
    xf.clear();
    src.clear();
  }
}

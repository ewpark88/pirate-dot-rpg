import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/ship_hp_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/ship_skins.dart';
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

  /// 배 그림 배율 (사용자 '조금만 더 줄여' — 화면 폭 약 15%). fx_map topShip.scale.
  late final double _shipScale = scene.fx.raw.obj('topShip').number('scale');
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
    // 환생 v2(S2 d9593dc): 그림 등급 = 명예 등급(shipTierLook), 스킨 = shipSkin(운영자 미리보기 skin이 있으면 그것), 보물 바다 = treasureSea.
    final tier = view.shipTierLook ?? scene.moments.shipTierId;
    final skinId = skin ?? view.shipSkin;
    _sea.gold = goldSea || view.treasureSea != null;
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
      ..storm = view.seaEvent?.id == 'storm'
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
        ..rotate(view.shipHeading)
        ..scale(_shipScale);
      _sea.wake(c, size.height / 2 - 4, size.height / 2, size.width / 2 * 0.6, clockMs);
      final sinking = _sink(c, m.sinkMs);
      final skinGlow = skinId != null && _skinGlow(skinId);
      final celebrate = m.glowMs > 0;
      _ship.paint(
        c,
        tier,
        view.shipLook,
        flash: scene.shipFlashMs > 0 && scene.settings.flash,
        // 부품 축하가 우선, 없으면 빛나는 스킨(phantom)의 돛이 은은하게 맥박.
        glowPart: celebrate ? m.glowPart : (skinGlow ? 'sail' : null),
        glow: celebrate ? 0.5 + 0.5 * math.sin(clockMs / 70) : (skinGlow ? 0.12 + 0.1 * math.sin(clockMs / 500) : 0),
        recoil: _recoil(clockMs - m.cannonFiredAtMs),
        skin: skinId != null && skins.ready(skinId) ? skinId : null,
      );
      if (sinking) c.restore();
      c.restore();
      final box = Rect.fromCenter(
        center: Offset.zero,
        width: size.width * _shipScale,
        height: size.height * _shipScale,
      );
      if (m.sinkMs <= 0) _hp.paint(c, box);
    }
    c
      ..save()
      ..translate(-ship.dx, -ship.dy);
    _enemies(c, under: false);
    if (view.seaEvent?.id == 'bottle') {
      final b = scene.bottleAt;
      sprites.draw(
        c,
        'td_event:bottle',
        b.dx.roundToDouble(),
        b.dy.roundToDouble(),
        frame: (clockMs / 400).floor() % 2,
      );
    }
    fx(c);
    c.restore();
    atmosphere.paintOver(c, viewRect, clockMs, powerSave: scene.settings.powerSave);
    if (view.feverTicksLeft > 0) _feverCoins(c, viewRect, clockMs);
    c.restore();
    _overlays(c, frame.box, clockMs);
  }

  late final double _recoilMs = scene.fx.raw.obj('shipParts').number('recoilMs');

  /// 발사 뒤 [since] ms의 반동 0~1 (발사 순간 1 → recoilMs에 0).
  double _recoil(double since) => since >= 0 && since < _recoilMs ? 1 - since / _recoilMs : 0;

  /// 환생 스킨 운영자 미리보기(없으면 BattleView.shipSkin) — 바뀌면 색 사본을 비동기로 만들고, 준비되면 그린다.
  String? skin;

  /// 보물 바다 금빛 물결 미리보기(운영자) — 실제는 BattleView.treasureSea.
  bool goldSea = false;

  final skins = ShipSkins();
  late final JsonReader _skinCfg = scene.fx.raw.obj('topShip').obj('skinPreview');

  /// 스킨 사본이 없으면 비동기로 만들기 시작한다. glow 스킨(phantom)이고 준비됐으면 true.
  bool _skinGlow(String id) {
    if (!_skinCfg.has(id)) return false;
    final cfg = _skinCfg.obj(id);
    final bank = sprites.bank;
    if (!skins.ready(id) && bank != null) {
      unawaited(
        skins.prepare(id, cfg, bank, [
          for (final t in scene.tables.shipTiers.tiers)
            for (final l in TopShipPainter.layers) 'td:${t.id}:$l',
        ]),
      );
    }
    return cfg.raw['glow'] == true && skins.ready(id);
  }

  late final JsonReader _fever = scene.fx.raw.obj('topEvents').obj('fever');
  late final Color _feverColor = Color(parseArgb(_fever.str('border'), 'topEvents.fever.border'));
  final _border = Paint()..style = PaintingStyle.stroke;
  final _overlay = Paint();

  /// 피버 금화 비: 보이는 영역 위에서 결정론적 자리로 떨어지며 회전(절전이면 반).
  void _feverCoins(Canvas c, Rect view, double ms) {
    final n = (_fever.integer('coins') * (scene.settings.powerSave ? 0.5 : 1)).round();
    const size = 9.0;
    for (var i = 0; i < n; i++) {
      final x = view.left + (i * 53 + 17) % view.width.toInt();
      final y = view.top + ((ms / (14 + i % 5)) + i * 41) % (view.height + 20) - 10;
      sprites.drawSmoothFrame(c, 'coin_hd', ((ms / 70).floor() + i) % 4, x, y, size, size);
    }
  }

  /// 상자 dp 위 덮개: 피버 금빛 테두리(맥박)·피버 시작 번쩍·폭풍 번개(번쩍임 설정이 켜졌을 때만).
  void _overlays(Canvas c, Size box, double ms) {
    final view = scene.frame;
    final flash = scene.settings.flash;
    if (view.feverTicksLeft > 0) {
      final pulse = 0.55 + 0.45 * math.sin(ms / _fever.number('pulseMs') * math.pi);
      final w = _fever.number('borderDp');
      // 안쪽으로 번지는 금빛(넓고 흐림) + 가장자리 금 테(선명)
      _border
        ..strokeWidth = w * 3
        ..color = _feverColor.withValues(alpha: 0.35 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w);
      c.drawRect((Offset.zero & box).deflate(w * 1.5), _border);
      _border
        ..strokeWidth = w
        ..color = _feverColor.withValues(alpha: 0.6 + 0.4 * pulse)
        ..maskFilter = null;
      c.drawRect((Offset.zero & box).deflate(w / 2), _border);
    }
    final f = scene.moments.feverFlashMs;
    if (f > 0 && flash) {
      _overlay.color = _feverColor.withValues(alpha: 0.35 * f / _fever.number('flashMs'));
      c.drawRect(Offset.zero & box, _overlay);
    }
    final l = atmosphere.lightning(ms);
    if (l > 0 && flash) {
      _overlay.color = Color.fromRGBO(240, 246, 255, 0.45 * l);
      c.drawRect(Offset.zero & box, _overlay);
    }
  }

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
      final key = (e.boss ? _bossKeys : _enemyKeys)[e.kind] ??= _keyFor(e.kind, boss: e.boss);
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

  /// 돌발 이벤트 적(황금 물고기·바다뱀·상인선)은 td_event 그림, 나머지는 td_enemy·td_boss.
  String _keyFor(String kind, {required bool boss}) {
    if (sprites.sheet('td_event:$kind') != null) return 'td_event:$kind';
    return boss ? 'td_boss:$kind' : 'td_enemy:$kind';
  }

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

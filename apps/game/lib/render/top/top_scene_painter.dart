import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/ship_hp_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/top/ship_skins.dart';
import 'package:pirate_dot/render/top/top_atmosphere.dart';
import 'package:pirate_dot/render/top/top_enemies.dart';
import 'package:pirate_dot/render/top/top_fever.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/render/top/top_marks.dart';
import 'package:pirate_dot/render/top/top_overlays.dart';
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
  late final TopOverlays _overlays = TopOverlays(scene, sprites, atmosphere);
  late final TopMarks _marks = TopMarks(scene, sprites);
  late final TopEnemies _foes = TopEnemies(scene, sprites);

  /// 피버 연출(세기 level은 발사체 불 꼬리에도 쓴다).
  late final TopFever fever = TopFever(scene);

  /// 배 그림 배율 (사용자 '조금만 더 줄여' — 화면 폭 약 15%). waves.top.shipScale — 엔진 선체 캡슐과 같은 키(platform-ship-hitbox).
  late final double _shipScale = scene.tables.waves.raw.obj('top').number('shipScale');
  late final TopAtmosphere atmosphere = TopAtmosphere(scene.fx.raw.obj('atmosphere'), sprites);

  double? _shipY;

  /// 지금 그린 배 중심 높이(상자 dp) — 테스트용.
  double? get drawnShipY => _shipY;
  double _lastMs = 0;
  static const _followMs = 220.0;
  static const _cullMargin = 24.0;

  /// 지금 프레임에 보이는 전장(전장 좌표, 여유 포함). ScenePainter가 발사체·이펙트·코인·숫자 컬링에 쓴다.
  Rect visibleWorld = Rect.largest;

  void paint(Canvas c, TopFrame frame, void Function(Canvas c) fx) {
    final clockMs = scene.clockMs;
    final dt = (clockMs - _lastMs).clamp(0.0, 100.0);
    _lastMs = clockMs;
    final target = frame.shipScreen.dy;
    final y = _shipY ?? target;
    // 시계가 안 가면(전투 멈춤·한 번만 다시 그리기) 따라가기 대신 바로 제자리 — 시트를 연 뒤 배가 옛 자리(선원 줄 밑)에 남던 것(S5 스토어 03_ship).
    _shipY = dt <= 0 ? target : y + (target - y) * math.min(1, dt / _followMs * 3);
    final dpr = frame.dpr;
    final sx = (frame.shipScreen.dx * dpr).roundToDouble() / dpr;
    // 피버 질주: 카메라를 앞으로 조금(배가 6dp 아래로) + 시작 가속(0.4초 동안 배가 20dp 위로 '쑥').
    final sy = ((_shipY! + 6 * fever.level - 20 * fever.lunge()) * dpr).roundToDouble() / dpr;
    final dot = frame.dot;
    final view = scene.frame;
    final ship = scene.topShip;
    final cam = scene.topCamera;
    _weave(ship.dx, clockMs, dt);
    // 환생 v2(S2 d9593dc): 그림 등급 = 명예 등급(shipTierLook), 스킨 = shipSkin(운영자 미리보기 skin이 있으면 그것), 보물 바다 = treasureSea.
    final tier = view.shipTierLook ?? scene.moments.shipTierId;
    final skinId = skin ?? view.shipSkin;
    _sea.gold = goldSea || view.treasureSea != null;
    c
      ..save()
      ..clipRect(Offset.zero & frame.box)
      // 피버 중 화면은 좌우로 움직이지 않는다(사용자 '화면이 좌우로 움직이면 조잡하다') — 흔들림은 세로만.
      ..translate(sx + (fever.level > 0 ? 0 : scene.shake.offsetX * dot), sy + scene.shake.offsetY * dot)
      ..scale(dot);
    final viewRect = Rect.fromLTWH(-sx / dot, -sy / dot, frame.box.width / dot, frame.box.height / dot);
    // 보이는 전장(전장 좌표) + 여유 — 화면 밖 적·발사체·이펙트·숫자는 그리지 않는다(S1 배터리).
    visibleWorld = viewRect.shift(cam).inflate(_cullMargin);
    fever.update(clockMs);
    _sea
      ..fever = fever.sea
      ..boost = fever.level
      ..advance(clockMs, 0) // 바다 흐름은 늘 세로(배가 대각선으로 꺾어도 배경은 좌우로 안 움직인다)
      ..paint(c, viewRect, clockMs);
    fever.rays(c, viewRect);
    final powerSave = scene.settings.powerSave;
    atmosphere
      ..storm = view.seaEvent?.id == 'storm'
      ..update(clockMs, scene.tables.regions.regionAt(view.stage).id, _sea.flow, 0, powerSave: powerSave)
      ..paintUnder(c, viewRect, clockMs, powerSave: powerSave);
    // 전장 좌표로: 카메라(바다 가운데·배 높이)가 원점.
    c
      ..save()
      ..translate(-cam.dx, -cam.dy);
    fever.weaveTrail(c, ship, clockMs, _sea.flowSpeed);
    _marks.zones(c);
    _foes.paint(c, under: true, cull: visibleWorld);
    c.restore();
    final size = _ship.sizeOf(tier);
    _shipR = size == null ? 16 : size.width * _shipScale / 2;
    if (size != null) {
      final m = scene.moments;
      // 배는 카메라에서 좌우로 비켜 그린다(피버 좌우 이동).
      c
        ..save()
        ..translate(ship.dx - cam.dx, ship.dy - cam.dy);
      fever
        ..aura(c, size.width * _shipScale / 2)
        ..wind(c, size.width * _shipScale / 2);
      c
        ..save()
        ..translate(_shipShake(clockMs), _surge(clockMs))
        ..rotate(_heading + _bank)
        // 질주: 앞으로 살짝 기울임(길이 방향 4% 눌림).
        ..scale(_shipScale, _shipScale * (1 - 0.04 * fever.level));
      _sea.wake(c, size.height / 2 - 4, size.height / 2, size.width / 2 * 0.6, clockMs);
      // 피버 시작 금빛 잔상: 가속 동안 배 실루엣 3개가 뒤로 처진다.
      final burst = fever.burst();
      if (burst > 0) {
        for (var k = 3; k >= 1; k--) {
          _ghost.colorFilter = ColorFilter.mode(Color.fromRGBO(255, 216, 74, 0.55 * burst / k), BlendMode.srcIn);
          c
            ..saveLayer(null, _ghost)
            ..translate(0, 9.0 * k * burst);
          _ship.paint(c, tier, view.shipLook);
          c.restore();
        }
      }
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
        billow: fever.level * (0.7 + 0.3 * math.sin(clockMs / 90)),
      );
      if (sinking) c.restore();
      c.restore();
      final box = Rect.fromCenter(
        center: Offset.zero,
        width: size.width * _shipScale,
        height: size.height * _shipScale,
      );
      if (m.sinkMs <= 0) {
        _marks.shipAura(c, box);
        _hp.paint(c, box);
      }
      c.restore();
    }
    c
      ..save()
      ..translate(-cam.dx, -cam.dy);
    _marks.chest(c, clockMs);
    scene.topHits.paint(
      c,
      clockMs,
      flash: scene.settings.flash,
      powerSave: scene.settings.powerSave,
      ship: scene.topShip,
    );
    _foes
      ..hotAt = fever.level > 0 ? _hot : null
      ..paint(c, under: false, cull: visibleWorld);
    fever.embers(c, scene.topShip);
    scene.topHits.paintOver(c, scene, clockMs, _shipR, _bossAt);
    _marks
      ..enemies(c, visibleWorld, _foes.radiusOf)
      ..bosses(c, _foes.radiusOf);
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
    if (view.feverTicksLeft > 0) _overlays.feverCoins(c, viewRect, clockMs);
    c.restore();
    _overlays.paint(c, frame.box, clockMs);
    fever
      ..rushers(c, frame.box)
      ..speedLines(c, frame.box);
    scene.topHits.fast.paintScreen(c, frame.box, clockMs, flash: scene.settings.flash);
    scene.topHits.bounty.paintScreen(c, frame.box, clockMs, sprites);
    _marks.screenFlash(c, Offset.zero & frame.box);
  }

  Offset? _bossAt(int id) {
    final p = scene.poseOf(id);
    return p == null ? null : Offset(p.drawX, p.drawY);
  }

  double _shipR = 16;
  final _ghost = Paint();

  double _prevX = double.nan;
  double _bank = 0;
  double _heading = 0;
  double _vx = 0;

  /// 피버 좌우 이동: x 변화로 뱅크(이동 방향으로 최대 15°, 부드럽게), 방향을 바꾸면 큰 물보라.
  void _weave(double x, double clockMs, double dt) {
    if (_prevX.isNaN || dt <= 0) {
      _prevX = x;
      return;
    }
    final vx = (x - _prevX) / dt * Duration.millisecondsPerSecond;
    _prevX = x;
    if (_vx.abs() > 12 && vx.abs() > 12 && vx.sign != _vx.sign) {
      scene.topHits.impact.add(x, scene.topShip.dy + 6, 30, 0xFFE6F6FF, clockMs, water: true);
    }
    _vx = vx;
    final target = (vx / 90).clamp(-1.0, 1.0) * 15 * math.pi / 180;
    // 엔진이 배 방향(shipHeading, 피버 지그재그 ±25°)을 주면 그 각도로 — 꺾을 때 약 0.25초에 빠르게 돌고, x 변화 뱅크는 쓰지 않는다.
    final heading = scene.frame.shipHeading;
    _heading += (heading - _heading) * math.min(1, dt / 80);
    _bank += ((heading != 0 ? 0 : target) - _bank) * math.min(1, dt / 120);
  }

  /// 피버 질주 위아래 흔들림(흔들기 설정 따름).
  double _surge(double clock) => scene.settings.shake ? math.sin(clock / 90) * 0.6 * fever.level : 0;

  bool _hot(double x, double y) => fever.melting(x, y, scene.topShip);

  /// 배 미세 흔들림(맞은 동안 ±0.8단위, 화면 흔들기 설정을 따른다).
  double _shipShake(double clock) =>
      scene.shipFlashMs > 0 && scene.settings.shake ? ((clock / 40).floor().isEven ? 0.8 : -0.8) : 0;

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
}

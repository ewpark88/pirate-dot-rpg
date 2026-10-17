import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/paint/hud_painter.dart';
import 'package:pirate_dot/render/paint/pb_fx_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/paint/stage_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/text/outline_digits.dart';
import 'package:pirate_dot/render/top/top_dim.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/render/top/top_scene_painter.dart';
import 'package:pirate_dot/render/top/top_wave_fx.dart';

part 'scene_painter_top.dart';

/// [BattleScene]을 캔버스에 그린다(스프라이트 없으면 단색 플레이스홀더). Flame 컴포넌트와 골든 테스트가 같이 쓴다.
/// 탑다운(T4-3 — 옆모습 paint는 지움): 바다·적·배는 TopScenePainter, 발사체·이펙트·코인·숫자는 여기(전장 좌표), HUD는 paintTop.
class ScenePainter {
  ScenePainter(this.scene) {
    _hud = HudPainter(scene, _sprite);
    _pb = PbFxPainter(scene, _sprite);
    _stage = StagePainter(scene, _sprite);
  }

  final BattleScene scene;
  late final StagePainter _stage;
  final _sprite = SpriteDraw();
  late final HudPainter _hud;

  /// 테두리 숫자 아틀라스(디자인 개편) — 넣으면 피해 숫자를 그것으로.
  OutlineDigits? get digits => _hud.digits;
  set digits(OutlineDigits? d) => _hud.digits = d;
  late final PbFxPainter _pb;
  final _topWave = TopWaveFx();

  /// 아트 팩 이미지(null이거나 키가 없으면 플레이스홀더). useSprites = 운영자 "스프라이트 끄기".
  SpriteBank? get sprites => _sprite.bank;
  set sprites(SpriteBank? v) => _sprite.bank = v;
  bool get useSprites => _sprite.enabled;
  set useSprites(bool v) => _sprite.enabled = v;

  /// 운영자 모드: 적 히트박스 표시 (탑다운은 아직 그리지 않는다 — 운영자 칩 호환).
  bool showHitboxes = false;

  /// 방치 절전 화면 밝기(0~1) — null이면 평소 그리기, 값이 있으면 TopDim만(BattleGame 방치 3분).
  double? dim;
  late final _dim = TopDim(scene);

  final _paint = Paint()..isAntiAlias = false;
  final _stroke = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  /// 옛 옆모습 그리기 자리(T4-3에서 지움) — 아무것도 그리지 않는다. 스토어 스크린샷 테스트(platform 레인)의
  /// 옆모습 갈래가 아직 부르므로 남긴다; S5가 그 갈래를 지우면 함께 지운다.
  void paint(Canvas canvas) {}

  /// 탑다운 장면 그리기 (운영자·테스트: top.atmosphere.offsetMs로 시간대 미리보기).
  late final TopScenePainter top = TopScenePainter(scene, _sprite);
  // ignore: prefer_function_declarations_over_variables — 메서드 tear-off는 프레임마다 클로저를 만든다 → 필드에 한 번만.
  late final void Function(Canvas c) _worldFx = (c) {
    _cull = top.visibleWorld; // top.paint가 이번 프레임 값을 넣은 뒤 불린다
    _projectiles(c);
    _effects(c);
    _coins(c);
    _hud.paintNumbers(c, scale: _numberScale, cull: _cull);
  };
  double _numberScale = 1;
  double _fxScale = 1;

  Rect _cull = Rect.largest;
  static const _liteBlasts = 4; // 이보다 폭발이 많으면 가벼운 폭발

  void _fill(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l.roundToDouble(), t.roundToDouble(), w.roundToDouble(), h.roundToDouble()), _paint);
  }

  void _projectiles(Canvas c) {
    for (final p in scene.projectiles.active) {
      if (!_cull.contains(Offset(p.x, p.y))) continue;
      if (scene.player.position < p.startIndex) continue;
      if (_pb.projectile(c, p)) continue;
      if (_sprite.draw(c, 'projectile:${p.family}', p.x, p.y)) continue;
      final s = p.style.size;
      _fill(c, p.x - s / 2, p.y - s / 2, s, s, p.style.color);
    }
  }

  void _effects(Canvas c) {
    var blasts = 0;
    for (final e in scene.effects.active) {
      if (e.sheetId == 'explosion_aoe' && e.visible) blasts++;
    }
    _pb.lite = scene.settings.powerSave || blasts > _liteBlasts;
    for (final e in scene.effects.active) {
      if (!e.visible || !_cull.contains(Offset(e.x, e.y))) continue;
      // 탑다운: 전장 1단위가 옆모습 1도트보다 커서 이펙트를 옆모습과 같은 화면 크기로(숫자와 같은 배율).
      final scaled = _fxScale != 1;
      if (scaled) {
        c
          ..save()
          ..translate(e.x, e.y)
          ..scale(_fxScale)
          ..translate(-e.x, -e.y);
      }
      _effect(c, e);
      if (scaled) c.restore();
    }
  }

  void _effect(Canvas c, Effect e) {
    if (e.sheetId == 'explosion_aoe' && _pb.blast(c, e)) return;
    if (e.sheetId == 'tidal_wave' && scene.isTop) return _topWave.paint(c, e); // 탑다운 해일(TopWaveFx)
    final cy = _bottomAnchored.contains(e.sheetId) ? e.y - e.h / 2 : e.y;
    if (_sprite.draw(c, 'fx:${e.sheetId}', e.x, cy, frame: e.frame, w: e.w, h: e.h)) return;
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

  late final JsonReader _coinCfg = scene.fx.raw.obj('coinFx');

  /// 큰 금화(fx/coin_hd.png 4프레임 회전): 화면 크기 coinFx.sizeDp dp 고정, 목표 가까이서 조금 작아진다.
  bool _coinHd(Canvas c, Coin coin) {
    final sheet = _sprite.sheet('coin_hd');
    if (sheet == null) return false;
    final t = (coin.ageMs / coin.flyMs).clamp(0.0, 1.0);
    // 폰은 sizeDp dp, 전장이 아주 큰 태블릿에서는 최소 minDots 필드 도트(전장 대비 너무 작지 않게).
    final base = math.max(_coinCfg.number('sizeDp') / (_pb.unitDp ?? scene.layout.dot), _coinCfg.number('minDots'));
    final size = base * (1 - 0.25 * t * t);
    final frame = (coin.ageMs / _coinCfg.number('spinFrameMs')).floor() % sheet.frames;
    return _sprite.drawSmoothFrame(c, 'coin_hd', frame, coin.x, coin.y, size, size * sheet.frameH / sheet.frameW);
  }

  /// 코인 반짝임 3프레임을 초당 12장 (기준 장면).
  static const _coinFps = 12;

  late final Set<String> _bottomAnchored = {
    for (final e in scene.fx.sheetAnchors.raw.entries)
      if (e.value == 'bottom') e.key,
  };

  void _coins(Canvas c) {
    for (final coin in scene.coins.active) {
      if (!_cull.contains(Offset(coin.x, coin.y))) continue;
      if (coin.ageMs < 0) continue;
      if (_coinHd(c, coin)) continue;
      if (_sprite.draw(c, 'coin', coin.x, coin.y, frame: (coin.ageMs * _coinFps / 1000).floor())) continue;
      _fill(c, coin.x - 1, coin.y - 1, 2, 2, 0xFFFFD23F);
    }
  }
}

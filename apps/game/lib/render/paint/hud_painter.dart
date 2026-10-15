import 'dart:ui';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/pixel_font.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';

/// 캔버스 안 HUD (기준 battle_ship.gif, render-quality-v1 규칙 4·5·8):
/// 도트 데미지 숫자, `xN COMBO` 배너, 왼쪽 위 코인+골드, 가운데 `스테이지-파`, 오른쪽 위 함성 게이지, 선원 슬롯 6칸.
class HudPainter {
  HudPainter(this.scene, this.sprites) : _family = {for (final c in scene.tables.crews.crews) c.id: c.family};

  final BattleScene scene;
  final SpriteDraw sprites;
  final Map<String, String> _family;

  final _paint = Paint()..isAntiAlias = false;

  final _stage = PixelText();
  final _timer = PixelText();
  final _combo = PixelText();
  int _stageShown = -1;
  int _waveShown = -1;
  int _timerShown = -1;

  FxMapTable get _fx => scene.fx;
  late final int _white = parseArgb(_fx.hud.str('textColor'), 'hud.textColor');
  late final int _goldColor = parseArgb(_fx.hud.str('goldColor'), 'hud.goldColor');
  late final int _rageFill = parseArgb(_fx.hud.str('rageFill'), 'hud.rageFill');
  late final int _rageFull = parseArgb(_fx.hud.str('rageFull'), 'hud.rageFull');
  late final int _barBack = parseArgb(_fx.hud.str('barBack'), 'hud.barBack');
  late final int _bossFill = parseArgb(_fx.hud.str('bossFill'), 'hud.bossFill');
  late final int _timerColor = parseArgb(_fx.hud.str('bossTimerColor'), 'hud.bossTimerColor');
  late final int _empty = parseArgb(_fx.slots.str('empty'), 'slots.empty');

  /// 보스 체력 막대 [왼, 위, 오른, 아래] — x는 보이는 영역 오른쪽 끝에서 잰다(음수).
  late final List<double> _bossBar = [for (final v in _fx.hud.raw['bossBar'] as List) (v as num).toDouble()];
  late final int _comboColor = parseArgb(_fx.combo.str('color'), 'combo.color');
  late final int _plate = parseArgb(_fx.slots.str('plate'), 'slots.plate');
  late final int _cooldown =
      ((_fx.slots.number('cooldownAlpha') * 0xFF).round() << 24) |
      (parseArgb(_fx.slots.str('cooldown'), 'slots.cooldown') & 0xFFFFFF);
  late final int _slotBar = parseArgb(_fx.backgroundLayout.str('slotBar'), 'backgroundLayout.slotBar');
  late final int _slotLine = parseArgb(_fx.backgroundLayout.str('slotLine'), 'backgroundLayout.slotLine');
  late final Map<String, int> _familyColor = {
    for (final e in _fx.familyColors.raw.entries) e.key: parseArgb(e.value as String, 'familyColors.${e.key}'),
  };

  /// 등급 순번(FleetSlot.rarity, 계약 I) → 테두리 색.
  late final List<int> _rarityColor = [
    for (final r in scene.tables.rarities.rarities) parseArgb(r.color, 'rarities.${r.id}.color'),
  ];

  static const _white32 = 0xFFFFFFFF;
  static const _skillBarPx = 2.0;

  void _fill(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l.roundToDouble(), t.roundToDouble(), w.roundToDouble(), h.roundToDouble()), _paint);
  }

  /// 데미지 숫자: 도트 글꼴, 0.6초 동안 떠오름. 글자는 숫자가 바뀔 때만 다시 굽는다.
  void paintNumbers(Canvas c) {
    final layer = scene.numbers;
    for (final n in layer.active) {
      final text = (n.cache ??= _NumberText()) as _NumberText;
      if (text.version != n.version || text.kind != n.kind) {
        text
          ..version = n.version
          ..kind = n.kind
          ..pixel.set(n.text, layer.colorOf(n), layer.scaleOf(n).round());
      }
      text.pixel.draw(c, n.x - text.pixel.width / 2, n.y - layer.riseOf(n));
    }
  }

  /// 캔버스 HUD (흔들림 밖, 화면 배치 v2): 위 가운데 스테이지-파, 그 아래 보스 남은 초, 오른쪽 위 보스 체력, 콤보.
  /// 골드는 UI 상단 바, 함성 게이지는 선원 줄 궁극기 버튼으로 옮겼다.
  void paintHud(Canvas c) {
    final f = scene.frame;
    final v = scene.layout.viewDots;
    if (f.stage != _stageShown || f.wave != _waveShown) {
      _stageShown = f.stage;
      _waveShown = f.wave;
      _stage.set('${f.stage}-${f.wave + 1}', _white, _textScale);
    }
    final cx = (v.left + v.width / 2).floorToDouble();
    _stage.draw(c, cx - (_stage.width / 2).floorToDouble(), v.top + _fx.hud.number('stageY'));
    if (f.bossActive) {
      final sec = (f.bossTicksLeft * scene.player.tickMs / Duration.millisecondsPerSecond).ceil();
      if (sec != _timerShown) {
        _timerShown = sec;
        _timer.set('$sec', _timerColor, _textScale);
      }
      final ty = v.top + _fx.hud.number('timerY');
      final gap = 2.0 * _textScale;
      final tx = cx - ((_timer.width + _skullW * _textScale + gap) / 2).floorToDouble();
      _skull(c, tx, ty, _textScale.toDouble());
      _timer.draw(c, tx + _skullW * _textScale + gap, ty);
    }
    final boss = _bossRatio(f);
    if (boss != null) {
      final (l, t, r, b) = (v.right + _bossBar[0], v.top + _bossBar[1], v.right + _bossBar[2], v.top + _bossBar[3]);
      _fill(c, l, t, r - l + 1, b - t + 1, _barBack);
      if (boss > 0) _fill(c, l + 1, t + 1, (r - l - 1) * boss, b - t - 1, _bossFill);
    }
    final combo = scene.combo.count(scene.clockMs);
    if (combo >= _fx.combo.integer('minKills')) {
      _combo
        ..set('x$combo COMBO', _comboColor, _fx.combo.integer('scale'))
        ..draw(c, _fx.combo.number('x'), v.top + _fx.combo.number('y'));
    }
  }

  static double? _bossRatio(BattleView f) {
    for (final e in f.enemies) {
      if (e.boss) return e.hpRatio.clamp(0.0, 1.0);
    }
    return null;
  }

  static const _skullW = 5.0;

  /// HUD 글자 배율 — 1도트가 약 1dp인 폰에서도 읽히게 정수배(기준 gif '12-2' 비율).
  late final int _textScale = _fx.hud.integer('textScale');

  /// 보스 남은 초 앞 작은 해골 5×5 (×[s]).
  void _skull(Canvas c, double x, double y, double s) {
    _fill(c, x, y, 5 * s, 4 * s, _timerColor);
    _fill(c, x + s, y + 4 * s, s, s, _timerColor);
    _fill(c, x + 3 * s, y + 4 * s, s, s, _timerColor);
    _fill(c, x + s, y + s, s, s, _barBack);
    _fill(c, x + 3 * s, y + s, s, s, _barBack);
  }

  /// 선원 줄 (화면 배치 v2): 폭 전체 띠, 슬롯 6칸(빈 칸은 빈 테두리), 오른쪽 끝 궁극기 버튼(보스 도전 자리는 비움 — UI).
  /// 슬롯: 등급 색 두꺼운 테두리 안에 32px 초상을 꽉 채우고(넘치는 줄은 잘라냄), 왼쪽 위 계열 색 표식, 쿨타임 덮개,
  /// 방금 발사 = 흰 테두리, 스킬 막대(우리 추가).
  void paintSlots(Canvas c) {
    final layout = scene.layout;
    // 선원 줄은 필드와 다른 배율(줄 도트) — 줄 왼쪽 위로 옮겨 bandScale배 하고 줄 좌표로 그린다.
    c
      ..save()
      ..translate(layout.bandOrigin.dx, layout.bandOrigin.dy)
      ..scale(layout.bandScale);
    _fill(c, 0, 0, layout.bandWidth + 1, layout.bandHeight + 1, _slotBar);
    _fill(c, 0, 0, layout.bandWidth + 1, 1, _slotLine);
    final fleet = scene.frame.fleet;
    final s = _fx.slots;
    final bw = s.number('border');
    final (w, h) = (kSlotPlateSize.width, kSlotPlateSize.height);
    final (iw, ih) = (w - bw * 2, h - bw * 2);
    for (var i = 0; i < kSlotCount; i++) {
      final at = layout.slotInBand(i);
      final (x, y) = (at.dx, at.dy);
      final (ix, iy) = (x + bw, y + bw);
      if (i >= fleet.length) {
        _fill(c, x, y, w, h, _slotLine);
        _fill(c, x + 1, y + 1, w - 2, h - 2, _empty);
        continue;
      }
      final slot = fleet[i];
      final family = _familyColor[_family[slot.crewId]] ?? _white32;
      _fill(
        c,
        x,
        y,
        w,
        h,
        scene.slotFlashMs[i] > 0 ? _white32 : _rarityColor[slot.rarity.clamp(0, _rarityColor.length - 1)],
      );
      _fill(c, ix, iy, iw, ih, _plate);
      c
        ..save()
        ..clipRect(Rect.fromLTWH(ix, iy, iw, ih));
      if (!sprites.draw(c, 'crew:${slot.crewId}', ix + kSlotSize / 2, iy - 1 + kSlotSize / 2)) {
        _fill(c, ix + 1, iy + 1, iw - 2, ih - 2, family);
      }
      c.restore();
      final rem = slot.cooldown.clamp(0.0, 1.0);
      if (rem > 0.02) _fill(c, ix, iy, iw, ih * rem, _cooldown);
      // 스킬 충전 막대(우리 추가): 차오르는 동안만 안쪽 아래 2px. 준비되면 사라진다.
      final skill = slot.skillCooldown.clamp(0.0, 1.0);
      if (skill > 0) _fill(c, ix, iy + ih - _skillBarPx, iw * (1 - skill), _skillBarPx, _goldColor);
      final badge = s.number('badge');
      _fill(c, ix, iy, badge, badge, family);
    }
    _ultimate(c, layout.ultimateInBand);
    c.restore();
  }

  static const _blinkMs = 250.0;

  /// 궁극기 버튼 그림: 2도트 테두리(가득 차면 금빛·흰빛 깜빡임) + 선장 초상 + 아래 함성 게이지. 누르는 건 UI.
  void _ultimate(Canvas c, Rect r) {
    final f = scene.frame;
    final rage = f.rage.clamp(0.0, 1.0);
    final full = rage >= 1;
    final blink = full && (scene.clockMs / _blinkMs).floor().isEven;
    _fill(c, r.left, r.top, r.width, r.height, blink ? _rageFull : _goldColor);
    final inner = r.deflate(2);
    _fill(c, inner.left, inner.top, inner.width, inner.height, _plate);
    final captain = f.captainId;
    if (captain != null) {
      c
        ..save()
        ..clipRect(inner);
      sprites.draw(
        c,
        'crew:$captain',
        inner.center.dx.floorToDouble(),
        (inner.top + kSlotSize / 2 - 1).floorToDouble(),
      );
      c.restore();
    }
    final gy = inner.bottom - _gaugePx;
    _fill(c, inner.left, gy, inner.width, _gaugePx, _barBack);
    if (rage > 0) _fill(c, inner.left, gy, inner.width * rage, _gaugePx, full ? _rageFull : _rageFill);
    if (!full) _fill(c, inner.left, inner.top, inner.width, (inner.height - _gaugePx) * (1 - rage), _cooldown);
    _bolt(c, inner.left + 1, inner.top + 1);
  }

  /// 궁극기 표시 번개 (5×8, 외곽선 포함) — 초상 위에 얹어 '누르는 버튼'으로 읽히게.
  static const _boltRows = ['.kkkk', 'kyyyk', 'kyyk.', 'kyyyk', '.kyyk', '.kyk.', 'kyk..', 'kk...'];

  void _bolt(Canvas c, double x, double y) {
    for (var dy = 0; dy < _boltRows.length; dy++) {
      final row = _boltRows[dy];
      for (var dx = 0; dx < row.length; dx++) {
        final ch = row[dx];
        if (ch == '.') continue;
        _fill(c, x + dx, y + dy, 1, 1, ch == 'y' ? _goldColor : _outline);
      }
    }
  }

  static const _outline = 0xFF1B1726;

  static const _gaugePx = 3.0;
}

/// 데미지 숫자 하나의 도트 글자. [DamageNumber.cache]에 붙어 풀과 함께 재사용된다.
class _NumberText {
  final pixel = PixelText();
  int version = -1;
  DamageKind? kind;
}

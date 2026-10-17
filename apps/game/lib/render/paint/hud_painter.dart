import 'dart:math' as math;
import 'dart:ui';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/combo_banner.dart';
import 'package:pirate_dot/render/paint/pixel_font.dart';
import 'package:pirate_dot/render/paint/slot_skin_painter.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';
import 'package:pirate_dot/render/text/outline_digits.dart';

/// 캔버스 안 HUD (기준 battle_ship.gif, render-quality-v1 규칙 4·5·8):
/// 도트 데미지 숫자, `xN COMBO` 배너, 왼쪽 위 코인+골드, 가운데 `스테이지-파`, 오른쪽 위 함성 게이지, 선원 슬롯 6칸.
class HudPainter {
  HudPainter(this.scene, this.sprites) : _family = {for (final c in scene.tables.crews.crews) c.id: c.family};

  final BattleScene scene;
  final SpriteDraw sprites;
  final Map<String, String> _family;

  final _paint = Paint()..isAntiAlias = false;

  /// 새 스킨 선원 줄(PB 초상이 있으면). 없으면 아래 도트 칸.
  late final _skin = SlotSkinPainter(scene, sprites);

  final _stage = PixelText();
  final _timer = PixelText();
  final _banner = ComboBanner();
  int _stageShown = -1;
  int _waveShown = -1;
  int _timerShown = -1;

  FxMapTable get _fx => scene.fx;
  late final int _white = parseArgb(_fx.hud.str('textColor'), 'hud.textColor');
  late final int _goldColor = parseArgb(_fx.hud.str('goldColor'), 'hud.goldColor');
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
  /// [scale]: 탑다운은 전장 1단위가 옆모습 1도트보다 커서(S24 2.13 : 1.42dp) 숫자를 옆모습과 같은 화면 크기로 줄인다.
  void paintNumbers(Canvas c, {double scale = 1, Rect cull = Rect.largest}) {
    // 손맛 v4: 연쇄가 길수록 숫자가 커지고 색이 달아오른다(흰 → 연노랑 → 주황 → 분홍), 나올 때 톡 튀어 커졌다 자리 잡음.
    final combo = scene.combo.count(scene.clockMs);
    final tier = combo >= 50 ? 3 : (combo >= 25 ? 2 : (combo >= 10 ? 1 : 0));
    final grow = 1 + math.min(combo, 60) / 60 * 0.45;
    // 쌓기 간격을 실제 그린 크기로(S5 실기기 '세로로 한 글자씩 쌓임'): 아틀라스 글자 배율 × 화면 배율(layout.dot/frame.dot —
    // 기기 dpr마다 다르다) × 연쇄 키움. 안 곱하면 큰 글자가 작은 줄 간격으로 쌓여 겹쳤다.
    final layer = scene.numbers
      ..tall = (digits != null ? 2.3 : 1) * scale * grow
      ..wide = (digits != null ? 1.5 : 1) * scale * grow;
    for (final n in layer.active) {
      if (!cull.contains(Offset(n.x, n.y))) continue;
      final text = (n.cache ??= _NumberText()) as _NumberText;
      final t = n.kind == DamageKind.normal ? tier : 0;
      if (text.version != n.version || text.kind != n.kind || text.tier != t) {
        text
          ..version = n.version
          ..kind = n.kind
          ..tier = t
          ..pixel.set(n.text, t == 0 ? layer.colorOf(n) : _comboTint[t - 1], layer.scaleOf(n).round());
      }
      final pop = _popScale(n);
      final d = digits;
      if (d != null) {
        _outlined(c, d, n, layer, scale * pop * (n.kind == DamageKind.ship ? 1 : grow), t);
        continue;
      }
      final s = scale * pop * (n.kind == DamageKind.ship ? 1 : grow);
      c
        ..save()
        ..translate(n.x, n.y)
        ..scale(s);
      text.pixel.draw(c, -text.pixel.width / 2, -layer.riseOf(n) / s * scale);
      c.restore();
    }
  }

  static const _comboTint = [0xFFFFF1A8, 0xFFFFB347, 0xFFFF7AC8];

  /// 쿵푸할매식 테두리 숫자 아틀라스(S2 outline_digits — BattleGame이 읽어 넣는다). 없으면 도트 글자.
  OutlineDigits? digits;

  /// 테두리 숫자: 보통 흰(연쇄 길면 금)·치명 금(크게)·배 피해 빨강. 칸 높이 = 도트 글자 높이의 약 2배.
  void _outlined(Canvas c, OutlineDigits d, DamageNumber n, DamageNumbers layer, double s, int tier) {
    final color = switch (n.kind) {
      DamageKind.ship => 'red',
      DamageKind.crit => 'gold',
      _ => tier >= 2 ? 'gold' : 'white',
    };
    final h = 5 * layer.scaleOf(n) * (n.kind == DamageKind.crit ? 3.0 : 2.3);
    final w = d.layout.measure(n.text, height: h);
    c
      ..save()
      ..translate(n.x, n.y - layer.riseOf(n))
      ..scale(s);
    d.paint(c, Offset(-w / 2, -h / 2), n.text, color: color, height: h);
    c.restore();
  }

  /// 나올 때 크기: 치명은 0.5 → 1.55 → 1(160ms, 넘쳤다 돌아옴), 보통은 0.7 → 1.15 → 1(110ms).
  static double _popScale(DamageNumber n) {
    final crit = n.kind == DamageKind.crit;
    final ms = crit ? 160.0 : 110.0;
    final t = n.ageMs / ms;
    if (t >= 1) return 1;
    final (from, peak) = crit ? (0.5, 1.55) : (0.7, 1.15);
    return t < 0.55 ? from + (peak - from) * (t / 0.55) : peak + (1 - peak) * ((t - 0.55) / 0.45);
  }

  /// 캔버스 HUD (흔들림 밖, 화면 배치 v2): 위 가운데 스테이지-파, 그 아래 보스 남은 초, 오른쪽 위 보스 체력, 콤보.
  /// 골드는 UI 상단 바, 함성 게이지는 선원 줄 궁극기 버튼으로 옮겼다.
  /// [top]: 탑다운(사용자 실기기 지적) — 스테이지 글자·보스 타이머·보스 체력 막대는 UI 게이지가 대신하므로 안 그리고, 콤보는 게이지 아래로.
  void paintHud(Canvas c, {bool top = false}) {
    final f = scene.frame;
    final v = scene.layout.viewDots;
    if (top) {
      // 빠른 항해 돌파 중엔 콤보 배너를 쉰다 — 격파 스탬프의 ×N이 같은 숫자를 맡는다(피드백 #20 '조잡하지 않게').
      if (f.fastSail == null) _comboAt(c, v.top + v.height * _topComboAt);
      return;
    }
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
    _comboAt(c, v.top + _fx.combo.number('y'));
  }

  static const _topComboAt = 0.18;

  void _comboAt(Canvas c, double y) {
    final v = scene.layout.viewDots;
    final now = scene.clockMs;
    _banner.paint(
      c,
      (v.left + v.width / 2).floorToDouble(),
      y,
      scene.combo.count(now),
      now,
      scene.combo.lastAddMs,
      minKills: _fx.combo.integer('minKills'),
      baseColor: _comboColor,
      fever: scene.frame.feverTicksLeft > 0,
      onMilestone: (_) {
        scene.shake.trigger(scene.juice.shake['aoe']!);
        scene.sound.sfx('multiKill', clockMs: now);
      },
    );
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
    if (_skin.paint(c)) {
      c.restore();
      return;
    }
    _fill(c, 0, 0, layout.bandWidth + 1, layout.bandFill + 1, _slotBar);
    _fill(c, 0, 0, layout.bandWidth + 1, 1, _slotLine);
    final fleet = scene.frame.fleet;
    final s = _fx.slots;
    final bw = s.number('border');
    for (var i = 0; i < kSlotCount; i++) {
      final rect = layout.slotRectInBand(i);
      final (x, y, w, h) = (rect.left, rect.top, rect.width, rect.height);
      final (iw, ih) = (w - bw * 2, h - bw * 2);
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
    c.restore();
  }
}

/// 데미지 숫자 하나의 도트 글자. [DamageNumber.cache]에 붙어 풀과 함께 재사용된다.
class _NumberText {
  final pixel = PixelText();
  int version = -1;
  DamageKind? kind;
  int tier = 0;
}

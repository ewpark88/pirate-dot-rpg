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
  final _gold = PixelText();
  final _combo = PixelText();
  String _goldShown = '';
  int _stageShown = -1;
  int _waveShown = -1;

  FxMapTable get _fx => scene.fx;
  late final int _white = parseArgb(_fx.hud.str('textColor'), 'hud.textColor');
  late final int _goldColor = parseArgb(_fx.hud.str('goldColor'), 'hud.goldColor');
  late final int _rageFill = parseArgb(_fx.hud.str('rageFill'), 'hud.rageFill');
  late final int _rageFull = parseArgb(_fx.hud.str('rageFull'), 'hud.rageFull');
  late final int _rageBack = parseArgb(_fx.hud.str('rageBack'), 'hud.rageBack');
  late final List<double> _rage = [for (final v in _fx.hud.raw['rage'] as List) (v as num).toDouble()];
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

  /// HUD (흔들림 밖): 골드·스테이지·게이지·콤보.
  void paintHud(Canvas c) {
    final f = scene.frame;
    sprites.draw(c, 'coin', 8, 8);
    final gold = f.gold.isZero ? '0' : f.gold.format();
    if (gold != _goldShown) {
      _goldShown = gold;
      _gold.set(gold, _goldColor, 1);
    }
    _gold.draw(c, 14, 6);
    if (f.stage != _stageShown || f.wave != _waveShown) {
      _stageShown = f.stage;
      _waveShown = f.wave;
      _stage.set('${f.stage}-${f.wave + 1}', _white, 1);
    }
    _stage.draw(c, _fx.hud.number('stageX'), _fx.hud.number('stageY'));
    final (l, t, r, b) = (_rage[0], _rage[1], _rage[2], _rage[3]);
    _fill(c, l, t, r - l + 1, b - t + 1, _rageBack);
    final rage = f.rage.clamp(0.0, 1.0);
    if (rage > 0) _fill(c, l + 1, t + 1, (r - l - 2) * rage, b - t - 1, rage >= 1 ? _rageFull : _rageFill);
    final combo = scene.combo.count(scene.clockMs);
    if (combo >= _fx.combo.integer('minKills')) {
      _combo
        ..set('x$combo COMBO', _comboColor, _fx.combo.integer('scale'))
        ..draw(c, _fx.combo.number('x'), _fx.combo.number('y'));
    }
  }

  /// 선원 슬롯 6칸 (render-quality-v2): 등급 색 두꺼운 테두리 안에 32px 초상을 꽉 채우고(넘치는 줄은 잘라냄),
  /// 왼쪽 위 계열 색 표식, 쿨타임 덮개, 방금 발사 = 흰 테두리, 스킬 막대(우리 추가).
  void paintSlots(Canvas c) {
    _fill(c, 0, kFieldBottom, kLogicalWidth, kLogicalHeight - kFieldBottom, _slotBar);
    _fill(c, 0, kFieldBottom, kLogicalWidth, 1, _slotLine);
    final fleet = scene.frame.fleet;
    final s = _fx.slots;
    final (x0, step, w, h, bw) = (
      s.number('x'),
      s.number('step'),
      s.number('plateW'),
      s.number('plateH'),
      s.number('border'),
    );
    final (iw, ih) = (w - bw * 2, h - bw * 2);
    final iy = kSlotTop + bw;
    for (var i = 0; i < fleet.length && i < kMaxSlots; i++) {
      final x = x0 + i * step;
      final ix = x + bw;
      final slot = fleet[i];
      final family = _familyColor[_family[slot.crewId]] ?? _white32;
      _fill(
        c,
        x,
        kSlotTop,
        w,
        h,
        scene.slotFlashMs[i] > 0 ? _white32 : _rarityColor[slot.rarity.clamp(0, _rarityColor.length - 1)],
      );
      _fill(c, ix, iy, iw, ih, _plate);
      c
        ..save()
        ..clipRect(Rect.fromLTWH(ix, iy, iw, ih));
      if (!sprites.draw(c, 'crew:${slot.crewId}', ix + kSlotSize / 2, s.number('portraitTop') + kSlotSize / 2)) {
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
  }
}

/// 데미지 숫자 하나의 도트 글자. [DamageNumber.cache]에 붙어 풀과 함께 재사용된다.
class _NumberText {
  final pixel = PixelText();
  int version = -1;
  DamageKind? kind;
}

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
  final _stroke = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

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

  /// 선원 슬롯 6칸: 판 + 계열 색 테두리, 32px 초상, 쿨타임 덮개, 방금 발사 = 흰 테두리, 스킬 막대(우리 추가).
  void paintSlots(Canvas c) {
    _fill(c, 0, kFieldBottom, kLogicalWidth, kLogicalHeight - kFieldBottom, _slotBar);
    _fill(c, 0, kFieldBottom, kLogicalWidth, 1, _slotLine);
    final fleet = scene.frame.fleet;
    final x0 = _fx.slots.number('x');
    final step = _fx.slots.number('step');
    for (var i = 0; i < fleet.length && i < kMaxSlots; i++) {
      final x = x0 + i * step;
      final slot = fleet[i];
      final color = _familyColor[_family[slot.crewId]] ?? _white32;
      _fill(c, x, kSlotTop, kSlotPlateW, kSlotPlateH, _plate);
      _stroke.color = Color(color);
      c.drawRect(Rect.fromLTWH(x + 0.5, kSlotTop + 0.5, kSlotPlateW - 1, kSlotPlateH - 1), _stroke);
      if (!sprites.draw(c, 'crew:${slot.crewId}', x + 1 + kSlotSize / 2, kSlotTop - 1 + kSlotSize / 2)) {
        _fill(c, x + 2, kSlotTop + 2, kSlotSize - 2, kSlotPlateH - 4, color);
      }
      final rem = slot.cooldown.clamp(0.0, 1.0);
      if (rem > 0.02) _fill(c, x + 1, kSlotTop + 1, kSlotSize, (kSlotPlateH - 1) * rem, _cooldown);
      // 스킬 충전 막대(우리 추가): 차오르는 동안만 판 아래 2px. 준비되면 사라진다 — 계열 색 테두리는 그대로(기준 화면).
      final skill = slot.skillCooldown.clamp(0.0, 1.0);
      if (skill > 0) {
        _fill(c, x + 1, kSlotTop + kSlotPlateH - 1 - _skillBarPx, kSlotSize * (1 - skill), _skillBarPx, _goldColor);
      }
      if (scene.slotFlashMs[i] > 0) {
        _stroke.color = const Color(_white32);
        c.drawRect(Rect.fromLTWH(x + 0.5, kSlotTop + 0.5, kSlotPlateW - 1, kSlotPlateH - 1), _stroke);
      }
    }
  }
}

/// 데미지 숫자 하나의 도트 글자. [DamageNumber.cache]에 붙어 풀과 함께 재사용된다.
class _NumberText {
  final pixel = PixelText();
  int version = -1;
  DamageKind? kind;
}

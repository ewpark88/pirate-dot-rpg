import 'dart:ui';

import 'package:flutter/painting.dart' show FontWeight, Shadow, TextPainter, TextSpan, TextStyle;
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';

/// 데미지 숫자와 선원 슬롯(초상·쿨타임 덮개·스킬 막대·발사 번쩍임).
class HudPainter {
  HudPainter(this.scene, this.sprites);

  final BattleScene scene;
  final SpriteDraw sprites;

  final _paint = Paint()..isAntiAlias = false;
  final _stroke = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final _layerPaint = Paint();
  final Map<String, int> _kindColor = {};

  static const _slotBar = 0xFF2B1D14;
  static const _cooldown = 0xB0000000;
  static const _white = Color(0xFFFFFFFF);
  static const _palette = [0xFFE74C3C, 0xFFF39C12, 0xFF9B59B6, 0xFF1ABC9C, 0xFFE67E22, 0xFFECF0F1, 0xFF2ECC71];
  static const _fadeStart = 0.7;
  static const _skillBarPx = 3.0;
  static const _blinkMs = 250;

  late final int _gold = parseArgb(scene.fx.shipSkill.str('buffColor'), 'shipSkill.buffColor');

  void _fill(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l.roundToDouble(), t.roundToDouble(), w.roundToDouble(), h.roundToDouble()), _paint);
  }

  int _colorOf(String id) => _kindColor[id] ??= _palette[id.codeUnits.fold(0, (a, b) => a + b) % _palette.length];

  void paintNumbers(Canvas c) {
    final layer = scene.numbers;
    for (final n in layer.active) {
      final text = (n.cache ??= _NumberText()) as _NumberText;
      if (text.version != n.version || text.kind != n.kind) text.layout(n, layer);
      final fade = n.ageMs / layer.spec.lifeMs;
      final dy = layer.riseOf(n);
      if (fade > _fadeStart) {
        _layerPaint.color = Color.fromRGBO(0, 0, 0, (1 - fade) / (1 - _fadeStart));
        c.saveLayer(null, _layerPaint);
      }
      text.painter.paint(
        c,
        Offset((n.x - text.painter.width / 2).roundToDouble(), (n.y - dy - text.painter.height).roundToDouble()),
      );
      if (fade > _fadeStart) c.restore();
    }
  }

  void paintSlots(Canvas c) {
    _fill(c, 0, kFieldBottom, kLogicalWidth, kLogicalHeight - kFieldBottom, _slotBar);
    final fleet = scene.frame.fleet;
    for (var i = 0; i < fleet.length && i < kMaxSlots; i++) {
      final x = kSlotGap + i * (kSlotSize + kSlotGap);
      final slot = fleet[i];
      const half = kSlotSize / 2;
      if (!sprites.draw(c, 'crew:${slot.crewId}', x + half, kSlotTop + half, w: kSlotSize, h: kSlotSize)) {
        _fill(c, x, kSlotTop, kSlotSize, kSlotSize, _colorOf(slot.crewId));
      }
      _fill(c, x, kSlotTop, kSlotSize, kSlotSize * slot.cooldown.clamp(0.0, 1.0), _cooldown);
      // 스킬 쿨타임: 초상 아래 막대가 차오르고, 다 차면 금색 테두리가 깜빡인다.
      final skillReady = 1 - slot.skillCooldown.clamp(0.0, 1.0);
      _fill(c, x, kSlotTop + kSlotSize - _skillBarPx, kSlotSize, _skillBarPx, _cooldown);
      _fill(c, x, kSlotTop + kSlotSize - _skillBarPx, kSlotSize * skillReady, _skillBarPx, _gold);
      if (slot.skillCooldown <= 0 && (scene.clockMs ~/ _blinkMs).isEven) {
        _stroke.color = Color(_gold);
        c.drawRect(Rect.fromLTWH(x - 1, kSlotTop - 1, kSlotSize + 2, kSlotSize + 2), _stroke);
      }
      if (scene.slotFlashMs[i] > 0) {
        _stroke.color = _white;
        c.drawRect(Rect.fromLTWH(x, kSlotTop, kSlotSize, kSlotSize), _stroke);
      }
    }
  }
}

/// 데미지 숫자 하나의 배치된 글자. [DamageNumber.cache]에 붙어 풀과 함께 재사용된다.
class _NumberText {
  final painter = TextPainter(textDirection: TextDirection.ltr);
  int version = -1;
  DamageKind? kind;

  static const _basePx = 4.0;

  void layout(DamageNumber n, DamageNumbers layer) {
    version = n.version;
    kind = n.kind;
    painter
      ..text = TextSpan(
        text: n.text,
        style: TextStyle(
          fontSize: _basePx * layer.scaleOf(n),
          fontWeight: FontWeight.bold,
          color: Color(layer.colorOf(n)),
          shadows: const [Shadow(offset: Offset(1, 1))],
        ),
      )
      ..layout();
  }
}

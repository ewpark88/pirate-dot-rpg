import 'dart:ui';

import 'package:flutter/painting.dart' show FontWeight, Shadow, TextPainter, TextSpan, TextStyle;
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';

/// [BattleScene]을 캔버스에 그린다 (아트 전 단색 플레이스홀더). Flame 컴포넌트와 골든 테스트가 같이 쓴다.
///
/// 그리는 순서: 배경 → 물속 적 → 배 → 물위 적 → 공중 적 → 발사체 → 이펙트 → 코인 → 숫자 → (흔들림 밖) 슬롯·플래시.
class ScenePainter {
  ScenePainter(this.scene);

  final BattleScene scene;

  /// 운영자 모드: 적 히트박스 표시.
  bool showHitboxes = false;

  final _paint = Paint()..isAntiAlias = false;
  final _stroke = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final _layerPaint = Paint();
  final Map<String, int> _kindColor = {};

  static const _sky = Color(0xFF7EC8E3);
  static const _sea = Color(0xFF1B4F72);
  static const _deep = Color(0xFF133A55);
  static const _slotBar = Color(0xFF2B1D14);
  static const _ship = Color(0xFF8B5A2B);
  static const _shipDeck = Color(0xFFC49A6C);
  static const _white = Color(0xFFFFFFFF);
  static const _hpBack = Color(0xFF3A0D0D);
  static const _hpFront = Color(0xFF5BD75B);
  static const _cooldown = Color(0xB0000000);
  static const _hitbox = Color(0xFFFF00FF);
  static const _underwaterTint = Color(0xFF0B2A44);
  static const _palette = [0xFFE74C3C, 0xFFF39C12, 0xFF9B59B6, 0xFF1ABC9C, 0xFFE67E22, 0xFFECF0F1, 0xFF2ECC71];
  static const _bossColor = 0xFF4A2C2A;

  void paint(Canvas canvas) {
    canvas
      ..save()
      ..translate(scene.shake.offsetX, scene.shake.offsetY);
    _background(canvas);
    _enemies(canvas, 'underwater');
    _shipBody(canvas);
    _enemies(canvas, 'surface');
    _enemies(canvas, 'air');
    _projectiles(canvas);
    _effects(canvas);
    _coins(canvas);
    _numbers(canvas);
    canvas.restore();
    _slots(canvas);
    if (scene.screenFlashMs > 0) _fill(canvas, 0, 0, kLogicalWidth, kFieldBottom, 0x99FFFFFF);
  }

  void _fill(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l.roundToDouble(), t.roundToDouble(), w.roundToDouble(), h.roundToDouble()), _paint);
  }

  void _background(Canvas c) {
    _fill(c, 0, 0, kLogicalWidth, kHorizonY, _sky.toARGB32());
    _fill(c, 0, kHorizonY, kLogicalWidth, kWaterlineY - kHorizonY, _sea.toARGB32());
    _fill(c, 0, kWaterlineY, kLogicalWidth, kFieldBottom - kWaterlineY, _deep.toARGB32());
  }

  void _shipBody(Canvas c) {
    final flash = scene.shipFlashMs > 0 && scene.settings.flash;
    _fill(c, kShipLeft, kShipTop + kShipHeight / 2, kShipWidth, kShipHeight / 2, flash ? 0xFFFFFFFF : _ship.toARGB32());
    _fill(c, kShipLeft + 8, kShipTop, 4, kShipHeight / 2, flash ? 0xFFFFFFFF : _shipDeck.toARGB32());
    _fill(c, kShipLeft + 28, kShipTop + 4, 18, 14, flash ? 0xFFFFFFFF : _shipDeck.toARGB32());
    // 배 HP 바.
    _fill(c, kShipLeft + 2, kShipTop - 5, kShipWidth - 4, 2, _hpBack.toARGB32());
    _fill(c, kShipLeft + 2, kShipTop - 5, (kShipWidth - 4) * scene.shipHpRatio, 2, _hpFront.toARGB32());
  }

  int _colorOf(String kind) => _kindColor[kind] ??= _palette[kind.codeUnits.fold(0, (a, b) => a + b) % _palette.length];

  void _enemies(Canvas c, String layer) {
    for (var k = 0; k < scene.poseCount; k++) {
      final e = scene.poses[k];
      if (e.layer != layer || e.drawX > kLogicalWidth + kBossSize) continue;
      _enemy(c, e);
    }
  }

  void _enemy(Canvas c, EnemyPose e) {
    final size = e.boss ? kBossSize : kEnemySize;
    final l = e.drawX - size / 2;
    final t = e.drawY - size / 2;
    var color = e.boss ? _bossColor : _colorOf(e.kind);
    if (e.layer == 'underwater') color = Color.lerp(Color(color), _underwaterTint, 0.45)!.toARGB32();
    _fill(c, l, t, size, size, e.flash ? 0xFFFFFFFF : color);
    if (e.boss || e.hpRatio < 1) {
      _fill(c, l, t - 3, size, 1, _hpBack.toARGB32());
      _fill(c, l, t - 3, size * e.hpRatio, 1, _hpFront.toARGB32());
    }
    if (showHitboxes) {
      _stroke.color = _hitbox;
      c.drawRect(Rect.fromLTWH(l, t, size, size), _stroke);
    }
  }

  void _projectiles(Canvas c) {
    for (final p in scene.projectiles.active) {
      if (scene.player.position < p.startIndex) continue;
      final s = p.style.size;
      _fill(c, p.x - s / 2, p.y - s / 2, s, s, p.style.color);
    }
  }

  void _effects(Canvas c) {
    for (final e in scene.effects.active) {
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
  }

  void _coins(Canvas c) {
    for (final coin in scene.coins.active) {
      _fill(c, coin.x - 1, coin.y - 1, 2, 2, 0xFFFFD23F);
    }
  }

  void _numbers(Canvas c) {
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

  static const _fadeStart = 0.7;

  void _slots(Canvas c) {
    _fill(c, 0, kFieldBottom, kLogicalWidth, kLogicalHeight - kFieldBottom, _slotBar.toARGB32());
    final fleet = scene.frame.fleet;
    for (var i = 0; i < fleet.length && i < kMaxSlots; i++) {
      final x = kSlotGap + i * (kSlotSize + kSlotGap);
      final slot = fleet[i];
      _fill(c, x, kSlotTop, kSlotSize, kSlotSize, _colorOf(slot.crewId));
      _fill(c, x, kSlotTop, kSlotSize, kSlotSize * slot.cooldown.clamp(0.0, 1.0), _cooldown.toARGB32());
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

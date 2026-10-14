import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show FontWeight, Shadow, TextPainter, TextSpan, TextStyle;
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/stage_painter.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';

/// [BattleScene]을 캔버스에 그린다 (아트 전 단색 플레이스홀더). Flame 컴포넌트와 골든 테스트가 같이 쓴다.
///
/// 그리는 순서: 배경 → 물속 적 → 배 → 물위 적 → 공중 적 → 발사체 → 이펙트 → 코인 → 숫자 → (흔들림 밖) 슬롯·플래시.
class ScenePainter {
  ScenePainter(this.scene) : _stage = StagePainter(scene);

  final BattleScene scene;
  final StagePainter _stage;

  /// 운영자 모드: 적 히트박스 표시.
  bool showHitboxes = false;

  final _paint = Paint()..isAntiAlias = false;
  final _stroke = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final _layerPaint = Paint();
  final Map<String, int> _kindColor = {};

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

  void paint(Canvas canvas) {
    canvas
      ..save()
      ..translate(scene.shake.offsetX, scene.shake.offsetY);
    _stage.paintBackground(canvas);
    _zones(canvas);
    _stage.paintChest(canvas);
    _enemies(canvas, 'underwater');
    _shipBody(canvas);
    _enemies(canvas, 'surface');
    _enemies(canvas, 'air');
    _projectiles(canvas);
    _effects(canvas);
    _coins(canvas);
    _numbers(canvas);
    canvas.restore();
    _stage.paintOverlays(canvas);
    _slots(canvas);
    if (scene.screenFlashMs > 0) _fill(canvas, 0, 0, kLogicalWidth, kFieldBottom, 0x99FFFFFF);
  }

  void _fill(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l.roundToDouble(), t.roundToDouble(), w.roundToDouble(), h.roundToDouble()), _paint);
  }

  void _shipBody(Canvas c) {
    final flash = scene.shipFlashMs > 0 && scene.settings.flash;
    _fill(c, kShipLeft, kShipTop + kShipHeight / 2, kShipWidth, kShipHeight / 2, flash ? 0xFFFFFFFF : _ship.toARGB32());
    _fill(c, kShipLeft + 8, kShipTop, 4, kShipHeight / 2, flash ? 0xFFFFFFFF : _shipDeck.toARGB32());
    _fill(c, kShipLeft + 28, kShipTop + 4, 18, 14, flash ? 0xFFFFFFFF : _shipDeck.toARGB32());
    // 배 HP 바.
    _fill(c, kShipLeft + 2, kShipTop - 5, kShipWidth - 4, 2, _hpBack.toARGB32());
    _fill(c, kShipLeft + 2, kShipTop - 5, (kShipWidth - 4) * scene.shipHpRatio, 2, _hpFront.toARGB32());
    // 배 스킬: 회복 번쩍임과 버프 테두리.
    if (scene.shipHealMs > 0 && scene.settings.flash) {
      _fill(c, kShipLeft, kShipTop, kShipWidth, kShipHeight, (0x88 << 24) | (_healColor & 0xFFFFFF));
    }
    if (scene.shipBuffMs > 0) {
      _stroke.color = Color(_buffColor);
      c.drawRect(const Rect.fromLTWH(kShipLeft, kShipTop, kShipWidth, kShipHeight), _stroke);
    }
  }

  late final int _healColor = parseArgb(scene.fx.shipSkill.str('healColor'), 'shipSkill.healColor');
  late final int _buffColor = parseArgb(scene.fx.shipSkill.str('buffColor'), 'shipSkill.buffColor');
  late final int _zoneColor =
      ((scene.fx.zone.number('alpha') * 0xFF).round() << 24) |
      (parseArgb(scene.fx.zone.str('color'), 'zone.color') & 0xFFFFFF);

  void _zones(Canvas c) {
    _paint.color = Color(_zoneColor);
    for (final z in scene.zones.active) {
      c.drawCircle(Offset(z.x.roundToDouble(), z.y.roundToDouble()), z.radius.roundToDouble(), _paint);
    }
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
    final looks = scene.looks;
    final bossShape = looks.bossOf(e.kind, boss: e.boss);
    final w = bossShape?.w ?? looks.sizeOf(e.kind);
    final h = bossShape?.h ?? w;
    final l = e.drawX - w / 2;
    final t = e.drawY - h / 2;
    var color = bossShape?.color ?? looks.colorOf(e.kind);
    if (e.layer == 'underwater') color = Color.lerp(Color(color), _underwaterTint, 0.45)!.toARGB32();
    if (bossShape == null) color = ((looks.alphaOf(e.kind) * 0xFF).round() << 24) | (color & 0xFFFFFF);
    _fill(c, l, t, w, h, e.flash ? 0xFFFFFFFF : color);
    if (bossShape != null || e.hpRatio < 1) {
      _fill(c, l, t - 3, w, 1, _hpBack.toARGB32());
      _fill(c, l, t - 3, w * e.hpRatio, 1, _hpFront.toARGB32());
    }
    final tierColor = looks.tierColor(e.tier);
    if (tierColor != null) _outline(c, l, t, w, h, 1, 1, tierColor);
    if (e.shielded) _outline(c, l, t, w, h, _shieldGap, _shieldPx, _shieldColor);
    if (e.stunned) _stars(c, e.drawX, t - 4);
    if (showHitboxes) {
      _stroke.color = _hitbox;
      c.drawRect(Rect.fromLTWH(l, t, w, h), _stroke);
    }
  }

  late final int _shieldColor = parseArgb(scene.fx.shield.str('color'), 'shield.color');
  late final double _shieldPx = scene.fx.shield.number('px');

  /// tier 테두리(1px) 바깥에 보호막이 오도록 띄우는 간격.
  static const _shieldGap = 3.0;

  /// 적 사각형 바깥 [gap]px에 [px] 두께 테두리.
  void _outline(Canvas c, double l, double t, double w, double h, double gap, double px, int color) {
    _stroke
      ..color = Color(color)
      ..strokeWidth = px;
    final o = gap - px / 2;
    c.drawRect(Rect.fromLTWH(l - o, t - o, w + o * 2, h + o * 2), _stroke);
    _stroke.strokeWidth = 1;
  }

  late final int _starColor = parseArgb(scene.fx.stun.str('color'), 'stun.color');
  late final double _starOrbit = scene.fx.stun.number('orbitPx');
  late final double _starPeriod = scene.fx.stun.number('periodMs');

  /// 기절: 머리 위에서 별 2개가 돈다.
  void _stars(Canvas c, double cx, double cy) {
    final a = scene.clockMs / _starPeriod * 2 * math.pi;
    for (var k = 0; k < 2; k++) {
      final ang = a + k * math.pi;
      _fill(c, cx + math.cos(ang) * _starOrbit - 1, cy + math.sin(ang) * _starOrbit / 2 - 1, 2, 2, _starColor);
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
      if (!e.visible) continue;
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
      if (coin.ageMs < 0) continue;
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
  static const _skillBarPx = 3.0;
  static const _blinkMs = 250;

  void _slots(Canvas c) {
    _fill(c, 0, kFieldBottom, kLogicalWidth, kLogicalHeight - kFieldBottom, _slotBar.toARGB32());
    final fleet = scene.frame.fleet;
    for (var i = 0; i < fleet.length && i < kMaxSlots; i++) {
      final x = kSlotGap + i * (kSlotSize + kSlotGap);
      final slot = fleet[i];
      _fill(c, x, kSlotTop, kSlotSize, kSlotSize, _colorOf(slot.crewId));
      _fill(c, x, kSlotTop, kSlotSize, kSlotSize * slot.cooldown.clamp(0.0, 1.0), _cooldown.toARGB32());
      // 스킬 쿨타임: 초상 아래 막대가 차오르고, 다 차면 금색 테두리가 깜빡인다.
      final skillReady = 1 - slot.skillCooldown.clamp(0.0, 1.0);
      _fill(c, x, kSlotTop + kSlotSize - _skillBarPx, kSlotSize, _skillBarPx, _cooldown.toARGB32());
      _fill(c, x, kSlotTop + kSlotSize - _skillBarPx, kSlotSize * skillReady, _skillBarPx, _buffColor);
      if (slot.skillCooldown <= 0 && (scene.clockMs ~/ _blinkMs).isEven) {
        _stroke.color = Color(_buffColor);
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

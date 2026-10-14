import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/juice/juice_settings.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';

/// 기록의 이벤트를 연출로 바꾼다 (docs/GAME_DESIGN.md 4.4 타격감 규칙, 수치는 juice.json·fx_map.json).
///
/// - 앞서 알림(onAhead, lookahead 틱 전): 발사체를 띄우고 슬롯을 번쩍인다.
/// - 지금(onNow): 피격 번쩍임·넉백·숫자·이펙트·흔들림·코인·진동.
class EventDirector implements ReplayListener {
  EventDirector(this.scene) : _crewFamily = _familyByCrew(scene.tables), _crewFx = _fxByCrew(scene.tables);

  final BattleScene scene;
  final Map<String, String> _crewFamily;
  final Map<String, String?> _crewFx;

  static Map<String, String> _familyByCrew(GameTables t) => {for (final c in t.crews.crews) c.id: c.family};
  static Map<String, String?> _fxByCrew(GameTables t) => {for (final c in t.crews.crews) c.id: c.fx};

  JuiceTable get _juice => scene.juice;
  RecordingPlayer get _player => scene.player;

  @override
  void onLoop() => scene.resetTransients();

  @override
  void onAhead(RecordedTick tick, int index) {
    for (final e in tick.events) {
      if (e is AttackFired) _launch(e, index, tick.frame);
    }
  }

  void _launch(AttackFired e, int index, BattleView frame) {
    final style = scene.fx.projectileFor(e.family);
    final start = (index - _juice.lookaheadTicks).toDouble();
    final tickMs = _player.tickMs;
    final targets = e.targetIds.isEmpty ? const [-1] : e.targetIds;
    for (final id in targets) {
      final target = id < 0 ? null : _player.enemyAt(index, id) ?? _player.enemyAt(index - 1, id);
      for (var b = 0; b < style.burst; b++) {
        scene.projectiles.obtain()
          ..style = style
          ..fromX = kShipNoseX
          ..fromY = kShipNoseY
          ..toX = target?.x ?? e.x
          ..toY = target?.y ?? e.y
          ..startIndex = start + b * style.burstGapMs / tickMs
          ..impactIndex = index.toDouble()
          ..progress = 0
          ..x = kShipNoseX
          ..y = kShipNoseY;
      }
    }
    for (var i = 0; i < frame.fleet.length && i < kMaxSlots; i++) {
      if (frame.fleet[i].crewId == e.crewId) scene.slotFlashMs[i] = _slotFlashMs;
    }
  }

  static const _slotFlashMs = 120.0;

  @override
  void onNow(RecordedTick tick, int index) {
    final f = tick.frame;
    scene.shipHpRatio = f.shipHpMax.isZero ? 0 : (f.shipHp / f.shipHpMax).toDouble().clamp(0.0, 1.0);
    for (final e in tick.events) {
      switch (e) {
        case AttackFired():
          final fxId = _crewFx[e.crewId];
          if (fxId != null) scene.spawnEffect(fxId, e.x, e.y);
        case Damage():
          _damage(e, tick, index);
        case AoeDamageSum():
          scene.numbers.add(e.total, e.x, e.y - kNumberLiftPx * 2, DamageKind.sum);
          scene.shake.trigger(_juice.shake['aoe']!);
        case Kill():
          _kill(e, index);
        case UltimateCast():
          _fx('ultimateCast', kUltimateX, kUltimateY);
          scene.shake.trigger(_juice.shake['ultimate']!);
          scene.haptic(HapticLevel.medium);
        case ShipDamaged():
          scene
            ..shipFlashMs = _juice.flashFrames * kFrameMs
            ..shipHpRatio = e.hpRatio;
        case BossCleared():
          _bossKill();
        default:
          break;
      }
    }
  }

  void _damage(Damage e, RecordedTick tick, int index) {
    final target = _player.enemyAt(index - 1, e.targetId) ?? _player.enemyAt(index, e.targetId);
    if (target == null) return;
    scene.numbers.add(
      e.amount,
      target.x,
      target.y - kNumberLiftPx,
      e.crit ? DamageKind.crit : DamageKind.normal,
    );
    _fx(e.crit ? 'critHit' : 'damage', target.x, target.y);
    if (e.crit) scene.haptic(HapticLevel.light);

    final family = _crewFamily[e.crewId];
    var dirX = 0.0;
    var dirY = 0.0;
    var px = 0.0;
    if (family == 'assault') {
      dirX = 1;
      px = _juice.knockbackPx['assault'] ?? 0;
    } else if (family == 'lob') {
      // 폭발 중심(같은 틱 같은 선원의 조준점)에서 바깥으로.
      final center = _aimOf(tick, e.crewId);
      if (center != null) {
        final dx = target.x - center.$1;
        final dy = target.y - center.$2;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 0) {
          final inv = 1 / len;
          dirX = dx * inv;
          dirY = dy * inv;
        } else {
          dirX = 1;
        }
        px = _juice.knockbackPx['explosion'] ?? 0;
      }
    }
    scene.hitEnemy(e.targetId, dirX: dirX, dirY: dirY, px: px);
  }

  (double, double)? _aimOf(RecordedTick tick, String? crewId) {
    for (final e in tick.events) {
      if (e is AttackFired && e.crewId == crewId) return (e.x, e.y);
    }
    return null;
  }

  void _kill(Kill e, int index) {
    _fx('kill', e.x, e.y);
    for (var c = 0; c < _juice.coinCount; c++) {
      final spread = _juice.coinCount <= 1 ? 0.0 : c / (_juice.coinCount - 1) * 2 - 1;
      scene.coins.obtain()
        ..fromX = e.x
        ..fromY = e.y
        ..toX = kShipCenterX
        ..toY = kShipCenterY
        ..spread = spread
        ..lift = _coinLiftPx + (c.isEven ? _coinLiftJitterPx : 0)
        ..ageMs = 0
        ..flyMs = _juice.coinFlyMs
        ..x = e.x
        ..y = e.y;
    }
    final wasBoss = _player.enemyAt(index - 1, e.targetId)?.boss ?? false;
    if (wasBoss) _bossKill();
  }

  static const _coinLiftPx = 10.0;
  static const _coinLiftJitterPx = 5.0;

  void _bossKill() {
    if (scene.slowMoMs > 0) return;
    scene.shake.trigger(_juice.shake['bossKill']!);
    scene.slowMoMs = _juice.bossSlowMoMs;
    if (_juice.bossFlash && scene.settings.flash) scene.screenFlashMs = _juice.flashFrames * kFrameMs * 2;
    _fx('bossCleared', kUltimateX, kUltimateY);
  }

  void _fx(String event, double x, double y) {
    final id = scene.fx.fxFor(event);
    if (id != null) scene.spawnEffect(id, x, y);
  }
}

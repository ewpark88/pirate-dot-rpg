import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/juice/juice_settings.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/coin_rain.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';
import 'package:pirate_dot/render/scene/fun_director.dart';
import 'package:pirate_dot/render/scene/m3_director.dart';
import 'package:pirate_dot/render/scene/projectile_rules.dart';
import 'package:pirate_dot/render/scene/ship_geometry.dart';
import 'package:pirate_dot/render/scene/top_view.dart';

part 'event_director_top.dart';

/// 기록의 이벤트를 연출로 바꾼다 (GAME_DESIGN 4.4, 수치는 juice·fx_map). 앞서 알림(onAhead, lookahead 틱 전): 발사체·슬롯
/// 번쩍임. 지금(onNow): 피격 번쩍임·넉백·숫자·이펙트·흔들림·코인·진동.
class EventDirector implements ReplayListener {
  EventDirector(this.scene)
    : _crewFamily = _familyByCrew(scene.tables),
      _crewFx = _fxByCrew(scene.tables),
      _m3 = M3Director(scene);

  final BattleScene scene;
  final M3Director _m3;
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
      if (e is BossFired && scene.isTop) _bossShot(e, index, tick.frame);
    }
  }

  void _launch(AttackFired e, int index, BattleView frame) {
    if (scene.isTop && e.family == _assault) return _topMelee(e, index, frame);
    final style = scene.fx.projectileFor(e.family);
    final ship = scene.topShip;
    final (tickMs, tip) = (
      _player.tickMs,
      scene.isTop ? Offset(e.fromX ?? ship.dx, e.fromY ?? ship.dy) : ShipGeometry.cannonTip(scene),
    );
    // 날아가는 시간(fx_map projectiles.<계열>.flightMs)만큼 앞서 띄운다 — 피해는 엔진 이벤트 시각 그대로(도착 = index).
    final flightTicks = math.min(_rules.flightMs(e.family) / tickMs, _juice.lookaheadTicks.toDouble());
    final start = index - flightTicks;
    // 범위 계열(투척·수중, fx_map single)은 조준점에 한 발 — 대상마다 따로 날리면 같은 자리에 포탄이 겹친다.
    final targets = e.targetIds.isEmpty || _rules.single(e.family) ? const [-1] : e.targetIds;
    for (final id in targets) {
      final target = id < 0 ? null : _player.enemyAt(index, id) ?? _player.enemyAt(index - 1, id);
      for (var b = 0; b < style.burst; b++) {
        scene.projectiles.obtain()
          ..style = style
          ..family = e.family
          ..crewId = e.crewId
          ..flat = scene.isTop
          ..fromX = tip.dx
          ..fromY = tip.dy
          ..toX = target == null ? e.x : (target.boss ? scene.layout.clampBossX(target.x) : target.x)
          ..toY = target?.y ?? e.y
          ..startIndex = start + b * style.burstGapMs / tickMs
          ..impactIndex = index.toDouble()
          ..progress = 0
          ..x = tip.dx
          ..y = tip.dy;
      }
    }
    if (scene.isTop) _topMuzzle(e, frame, tip, start);
    if (_muzzleFamilies.contains(e.family)) {
      final delayMs = math.max<double>(0, (start - _player.position) * tickMs / math.max(1, frame.speed));
      scene.spawnEffect(scene.fx.muzzle.str('fx'), tip.dx + 4, tip.dy + scene.shipBob, delayMs: delayMs);
      scene.moments.cannonFiredAtMs = scene.clockMs + delayMs;
    }
    _flashSlot(frame, e.crewId);
  }

  late final _rules = ProjectileRules(scene.fx, fallbackMs: _juice.lookaheadTicks * _player.tickMs);
  void _flashSlot(BattleView frame, String crewId) {
    for (var i = 0; i < frame.fleet.length && i < kMaxSlots; i++) {
      if (frame.fleet[i].crewId == crewId) scene.slotFlashMs[i] = _slotFlashMs;
    }
  }

  static const _slotFlashMs = 200.0;

  late final Set<String> _muzzleFamilies = {...scene.fx.muzzle.strs('families')};

  @override
  void onNow(RecordedTick tick, int index) {
    final f = tick.frame;
    scene.shipHpRatio = f.shipHpMax.isZero ? 0 : (f.shipHp / f.shipHpMax).toDouble().clamp(0.0, 1.0);
    final events = tick.events;
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      _sound(e);
      switch (e) {
        case AttackFired():
          final fxId = _crewFx[e.crewId];
          if (fxId != null) scene.spawnEffect(fxId, e.x, e.y);
        case ZoneSpawned():
          _m3.onZone(e);
        case SkillCast():
          _m3.onSkill(e);
          _flashSlot(tick.frame, e.crewId);
        case Damage():
          _damage(e, tick, index, number: e.crit || !_inVolley(events, i));
        case AoeDamageSum():
          scene.numbers.add(e.total, e.x, e.y - kNumberLiftPx * 2, DamageKind.sum);
          scene.shake.trigger(_juice.shake['aoe']!);
        case Kill():
          _kill(e, index);
        case UltimateCast():
          _m3.onUltimate(e, index);
          scene.shake.trigger(_juice.shake['ultimate']!);
          scene.haptic(HapticLevel.medium);
        case ShipDamaged():
          // 탑다운은 번쩍을 길게(부딪힘이 보이게, S1), 단 연달아 맞으면 300ms마다 한 번 — 옆모습은 그대로.
          if (!scene.isTop) {
            scene.shipFlashMs = _juice.flashFrames * kFrameMs;
          } else if (scene.topHits.takeFlash(scene.clockMs)) {
            scene.shipFlashMs = _kTopHitFlashMs;
          }
          scene
            ..shipHpRatio = e.hpRatio
            ..numbers.add(e.amount, _shipNumberAt(e).dx, _shipNumberAt(e).dy, DamageKind.ship);
          if (scene.isTop && e.fromX != null && e.fromY != null) scene.topHits.hit(scene, e.fromX!, e.fromY!);
          if (e.hpRatio <= 0 && !tick.frame.bossActive) scene.moments.onShipSunk();
        case BossCleared():
          _bossKill();
        case BossSpawned():
          scene.moments.onBossSpawned(e.kind, tick.frame.stage);
          if (scene.settings.flash) scene.bossWarnMs = scene.fx.bossEntrance.number('ms');
          scene.shake.trigger(_juice.shake['aoe']!);
        case ShipTierUp():
          scene.moments.onTierUp(e.tierId);
        case ShipLookChanged():
          scene.moments.onPartUp(e.part);
          funEvent(scene, e);
        case EnemyFired() when scene.isTop:
          _enemyShot(e, tick.frame);
        case EnemyEmerging() when scene.isTop:
          _emerging(e, tick.frame);
        case PartUpgraded(:final part) when scene.isTop:
          _partUp(part);
        case BossFailed():
          scene.bossFailMs = scene.fx.bossFailed.number('ms');
        default:
          funEvent(scene, e);
      }
    }
    _m3
      ..detectSplitRevive(tick, index)
      ..detectShieldBreak(tick, index);
  }

  /// 이벤트 → fx_map 효과음 키.
  void _sound(GameEvent e) {
    final key = switch (e) {
      Damage(:final crit) => crit ? 'critHit' : 'damage',
      Kill() => 'kill',
      MultiKill() => 'multiKill',
      SkillCast() => 'skillCast',
      UltimateCast() => 'ultimateCast',
      BossSpawned() => 'bossSpawned',
      BossCleared() => 'bossCleared',
      BossFailed() => 'bossFailed',
      _ => null,
    };
    if (key == null) return;
    final salt = e is Damage ? e.targetId : 0;
    scene.sound.sfx(key, clockMs: scene.clockMs, tick: e.tick, salt: salt);
  }

  /// 엔진은 범위 한 발의 Damage(·Kill)들 바로 뒤에 AoeDamageSum을 낸다 → 그 묶음이면 true.
  static bool _inVolley(List<GameEvent> events, int i) {
    for (var j = i + 1; j < events.length; j++) {
      final e = events[j];
      if (e is AoeDamageSum) return true;
      if (e is! Damage && e is! Kill) return false;
    }
    return false;
  }

  /// [number]가 false면 숫자 없이 피격 연출만 (범위 피해는 합산 숫자 하나 — 기준 장면 show=False).
  void _damage(Damage e, RecordedTick tick, int index, {required bool number}) {
    final target = _player.enemyAt(index - 1, e.targetId) ?? _player.enemyAt(index, e.targetId);
    if (target == null) return;
    final tx = target.boss ? scene.layout.clampBossX(target.x) : target.x;
    if (number) {
      scene.numbers.add(
        e.amount,
        tx,
        target.y - kNumberLiftPx,
        e.crit ? DamageKind.crit : DamageKind.normal,
        key: e.targetId,
      );
    }
    _fx(e.crit ? 'critHit' : 'damage', tx, target.y);
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
    scene.combo.add(scene.clockMs);
    _fx('kill', e.x, e.y);
    // 피버(탑다운): 처치 불꽃·코인 2배(사용자 '피버 임펙트').
    final fever = scene.isTop && scene.frame.feverTicksLeft > 0;
    if (fever) _fx('kill', e.x + 3, e.y - 3);
    final n = _juice.coinCount * (fever ? 2 : 1);
    final share = n <= 1 ? e.gold : e.gold.times(1 / n);
    final (tx, ty) = scene.coinTo;
    for (var c = 0; c < n; c++) {
      if (scene.coins.active.length >= _juice.maxCoins) {
        // 상한: 새 코인 대신 마지막 코인에 금액을 더한다(합계 보존, 화면은 덜 붐빈다).
        final last = scene.coins.active.last;
        last.amount = last.amount + share;
        continue;
      }
      final spread = n <= 1 ? ((e.targetId * 37) % 11 - 5) / 5 : c / (n - 1) * 2 - 1;
      scene.coins.obtain()
        ..fromX = e.x
        ..fromY = e.y
        ..toX = tx
        ..toY = ty
        ..spread = spread
        ..lift = _coinLiftPx + (c.isEven ? _coinLiftJitterPx : 0)
        ..fallPx = 0
        ..ageMs = 0
        ..flyMs = _juice.coinFlyMs
        ..amount = share
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
    coinRain(scene);
  }

  void _fx(String event, double x, double y) {
    final id = scene.fx.fxFor(event);
    if (id != null) scene.spawnEffect(id, x, y);
  }
}

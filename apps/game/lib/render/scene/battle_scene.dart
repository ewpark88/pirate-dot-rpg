import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/fx/pool.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/juice/juice_settings.dart';
import 'package:pirate_dot/render/juice/screen_shake.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';
import 'package:pirate_dot/render/scene/event_director.dart';

/// 맞은 적의 번쩍임·넉백 상태.
class HitState {
  int id = 0;
  double flashMs = 0;
  double knockAgeMs = 0;
  double knockMs = 0;
  double dirX = 0;
  double dirY = 0;
  double px = 0;
}

/// 운영자 모드·테스트가 읽는 숫자들. 객체 하나를 계속 고쳐 쓴다.
class SceneStats {
  int enemies = 0;
  int projectiles = 0;
  int effects = 0;
  int numbers = 0;
  int coins = 0;

  /// 풀·재사용 버퍼가 만든 객체 수. 워밍업 뒤에는 변하지 않아야 한다.
  int pooledObjects = 0;
}

/// 그릴 것 전부의 상태. Flame을 모르는 순수 Dart라 테스트가 직접 돌린다.
///
/// 기록 재생기 → [EventDirector](이벤트 → 발사체·이펙트·숫자·흔들림) → 이 장면 → 그리는 쪽(ScenePainter).
class BattleScene {
  /// [recording]이 null이면 라이브 모드: 엔진이 [push]로 매 틱을 넣는다.
  BattleScene(
    this.tables,
    List<RecordedTick>? recording, {
    JuiceSettings settings = const JuiceSettings(),
    bool loop = true,
    this.onHaptic,
  }) : juice = tables.juice,
       fx = tables.fxMap,
       _settings = settings {
    final tickMs = tables.waves.tickMs.toDouble();
    player = recording == null
        ? RecordingPlayer.live(
            tickMs: tickMs,
            lookaheadTicks: juice.lookaheadTicks,
            maxLagTicks: juice.liveMaxLagTicks,
          )
        : RecordingPlayer(recording, tickMs: tickMs, lookaheadTicks: juice.lookaheadTicks, loop: loop);
    projectiles = Pool(juice.maxProjectiles, Projectile.new);
    effects = Pool(juice.maxEffects, Effect.new);
    coins = Pool(juice.maxCoins, Coin.new);
    numbers = DamageNumbers(juice.damageNumber, juice.maxDamageNumbers);
    hits = Pool(_maxHits, HitState.new);
    player.listener = EventDirector(this);
    this.settings = settings;
  }

  static const _maxHits = 32;

  final GameTables tables;
  final JuiceTable juice;
  final FxMapTable fx;
  void Function(HapticLevel level)? onHaptic;

  late final RecordingPlayer player;
  late final Pool<Projectile> projectiles;
  late final Pool<Effect> effects;
  late final Pool<Coin> coins;
  late final DamageNumbers numbers;
  late final Pool<HitState> hits;
  final shake = ScreenShake();
  final stats = SceneStats();

  /// 선원 슬롯 발사 번쩍임 남은 시간(ms), 슬롯 순서.
  final slotFlashMs = List<double>.filled(kMaxSlots, 0);
  double shipFlashMs = 0;
  double screenFlashMs = 0;
  double slowMoMs = 0;
  double shipHpRatio = 1;

  JuiceSettings _settings;
  JuiceSettings get settings => _settings;
  set settings(JuiceSettings v) {
    _settings = v;
    shake.enabled = v.shake;
    if (!v.shake) shake.reset();
  }

  /// 라이브 모드 입력 (엔진 1틱 = 1번).
  void push(RecordedTick tick) => player.push(tick);

  BattleView get frame => player.isEmpty ? BattleView.empty : player.entryAt(player.position.floor()).frame;
  List<EnemyPose> get poses => player.poses;
  int get poseCount => player.poseCount;
  EnemyPose? poseOf(int id) => player.poseOf(id);

  /// 한 화면 프레임. [dtMs]는 실제 경과 시간.
  void update(double dtMs) {
    final rate = slowMoMs > 0 ? juice.bossSlowMoRate : 1.0;
    if (slowMoMs > 0) slowMoMs -= dtMs;
    player.advance(dtMs * rate);
    // 히트스톱 구간은 이펙트 시계도 멈춘다. 흔들림은 실제 시간으로 돈다.
    final fxDt = player.inHitStop ? 0.0 : dtMs * rate;
    _updateProjectiles();
    for (final e in effects.active) {
      e.ageMs += fxDt;
    }
    effects.releaseWhere(_effectDone);
    _updateCoins(fxDt);
    numbers.update(fxDt);
    shake.update(dtMs);
    for (var i = 0; i < kMaxSlots; i++) {
      if (slotFlashMs[i] > 0) slotFlashMs[i] -= dtMs;
    }
    if (shipFlashMs > 0) shipFlashMs -= fxDt;
    if (screenFlashMs > 0) screenFlashMs -= dtMs;
    _applyHits(fxDt);
    _updateStats();
  }

  static bool _effectDone(Effect e) => e.done;
  static bool _coinDone(Coin c) => c.done;
  static bool _projectileDone(Projectile p) => p.progress >= 1;
  static bool _hitDone(HitState h) => h.flashMs <= 0 && h.knockAgeMs >= h.knockMs;

  /// 이펙트 시트 한 번 재생. 상한을 넘으면 가장 오래된 것을 회수한다.
  void spawnEffect(String sheetId, double x, double y) {
    final sheet = fx.sheet(sheetId);
    if (sheet == null) return;
    effects.obtain()
      ..sheetId = sheetId
      ..x = x
      ..y = y
      ..w = sheet.w.toDouble()
      ..h = sheet.h.toDouble()
      ..frames = sheet.frames
      ..frameMs = fx.sheetFrameMs
      ..ageMs = 0
      ..color = fx.sheetColors[sheetId] ?? 0xFFFFFFFF;
  }

  /// 적 [id]가 맞았다: 번쩍임(설정이 켜져 있으면)과 넉백(방향 dirX·dirY, [px]).
  void hitEnemy(int id, {double dirX = 0, double dirY = 0, double px = 0}) {
    HitState? h;
    for (final s in hits.active) {
      if (s.id == id) h = s;
    }
    h ??= hits.obtain()
      ..id = id
      ..px = 0
      ..knockAgeMs = 0
      ..knockMs = 0;
    if (settings.flash) h.flashMs = juice.flashFrames * kFrameMs;
    if (px > 0) {
      h
        ..dirX = dirX
        ..dirY = dirY
        ..px = px
        ..knockAgeMs = 0
        ..knockMs = juice.knockbackMs;
    }
  }

  void haptic(HapticLevel level) {
    if (settings.vibration) onHaptic?.call(level);
  }

  /// 반복 재생으로 처음에 돌아가면 남은 연출을 비운다.
  void resetTransients() {
    projectiles.clear();
    effects.clear();
    coins.clear();
    numbers.clear();
    hits.clear();
    shake.reset();
    slowMoMs = 0;
    screenFlashMs = 0;
    shipFlashMs = 0;
  }

  void _updateProjectiles() {
    final pos = player.position;
    for (final p in projectiles.active) {
      if (pos < p.startIndex) {
        p.progress = 0;
        continue;
      }
      final total = player.motionBetween(p.startIndex, p.impactIndex);
      p.progress = total <= 0 ? 1 : (player.motionBetween(p.startIndex, pos) / total).clamp(0.0, 1.0);
      _placeProjectile(p);
    }
    projectiles.releaseWhere(_projectileDone);
  }

  static void _placeProjectile(Projectile p) {
    final t = p.progress;
    final s = p.style;
    switch (s.path) {
      case ProjectilePath.drop:
        p
          ..x = p.toX
          ..y = p.toY - s.arcPx * (1 - t);
      case ProjectilePath.line || ProjectilePath.arc || ProjectilePath.skip:
        p
          ..x = p.fromX + (p.toX - p.fromX) * t
          ..y = p.fromY + (p.toY - p.fromY) * t;
        if (s.path == ProjectilePath.arc) p.y -= s.arcPx * 4 * t * (1 - t);
        if (s.path == ProjectilePath.skip) p.y -= s.arcPx * math.sin(t * math.pi * _skipBounces).abs();
    }
  }

  static const _skipBounces = 3;

  void _updateCoins(double dtMs) {
    for (final c in coins.active) {
      c.ageMs += dtMs;
      final t = (c.ageMs / c.flyMs).clamp(0.0, 1.0);
      if (t < _fountainEnd) {
        final f = t / _fountainEnd;
        c
          ..x = c.fromX + c.spread * _fountainSpreadPx * f
          ..y = c.fromY - c.lift * math.sin(f * math.pi);
      } else {
        final f = (t - _fountainEnd) / (1 - _fountainEnd);
        final sx = c.fromX + c.spread * _fountainSpreadPx;
        final ease = f * f;
        c
          ..x = sx + (c.toX - sx) * ease
          ..y = c.fromY + (c.toY - c.fromY) * ease;
      }
    }
    coins.releaseWhere(_coinDone);
  }

  static const _fountainEnd = 0.4;
  static const _fountainSpreadPx = 10;

  void _applyHits(double dtMs) {
    for (final h in hits.active) {
      if (h.flashMs > 0) h.flashMs -= dtMs;
      if (h.knockAgeMs < h.knockMs) h.knockAgeMs += dtMs;
    }
    hits.releaseWhere(_hitDone);
    for (var k = 0; k < player.poseCount; k++) {
      final pose = player.poses[k];
      for (final h in hits.active) {
        if (h.id != pose.id) continue;
        pose.flash = settings.flash && h.flashMs > 0;
        if (h.knockMs > 0 && h.knockAgeMs < h.knockMs) {
          final k = h.px * (1 - h.knockAgeMs / h.knockMs);
          pose
            ..drawX = pose.x + h.dirX * k
            ..drawY = pose.y + h.dirY * k;
        }
      }
    }
  }

  void _updateStats() {
    stats
      ..enemies = player.poseCount
      ..projectiles = projectiles.active.length
      ..effects = effects.active.length
      ..numbers = numbers.active.length
      ..coins = coins.active.length
      ..pooledObjects =
          projectiles.created +
          effects.created +
          coins.created +
          numbers.pool.created +
          hits.created +
          player.poses.length;
  }
}

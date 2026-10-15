import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/fx/pool.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/juice/juice_settings.dart';
import 'package:pirate_dot/render/juice/screen_shake.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/enemy_look.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/backdrop.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';
import 'package:pirate_dot/render/scene/event_director.dart';
import 'package:pirate_dot/render/scene/moments.dart';
import 'package:pirate_dot/render/scene/motion.dart';
import 'package:pirate_dot/render/scene/scene_state.dart';
import 'package:pirate_dot/render/scene/sound_director.dart';

export 'package:pirate_dot/render/scene/scene_state.dart';

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
    EnemyLooks? looks,
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
    zones = Pool(fx.zone.integer('max'), Zone.new);
    this.looks = looks ?? EnemyLooks.fromTables(tables);
    backdrop = Backdrop(fx, tables.regions);
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
  late final Pool<Zone> zones;
  late final EnemyLooks looks;
  late final Backdrop backdrop;
  final shake = ScreenShake();
  final stats = SceneStats();
  final chest = ChestPose();
  late final combo = ComboTracker(windowMs: fx.combo.number('windowMs'));
  late final sound = SoundDirector(fx, juice);
  late final moments = Moments(this);

  /// 효과음·배경음 포트. null이면 무음.
  AudioPort? get audio => sound.audio;
  set audio(AudioPort? v) => sound.audio = v;
  List<String> get audioLog => sound.log;

  /// 선원 슬롯 발사 번쩍임 남은 시간(ms), 슬롯 순서.
  final slotFlashMs = List<double>.filled(kMaxSlots, 0);
  double shipFlashMs = 0;

  /// 배 스킬: 회복 번쩍임·버프 테두리 남은 시간(ms).
  double shipHealMs = 0;
  double shipBuffMs = 0;
  double screenFlashMs = 0;

  /// 보스 등장 경고·보스 실패 어두움 남은 시간(ms).
  double bossWarnMs = 0;
  double bossFailMs = 0;
  double slowMoMs = 0;
  double shipHpRatio = 1;

  /// 실제 경과 시간(ms) — 깜빡임 같은 장식용.
  double clockMs = 0;

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

  static double _down(double v, double dt) => v > 0 ? v - dt : v;

  /// 배 위아래 출렁임(px): round(sin(t·2)) — 기준 장면 그대로.
  double get shipBob => math.sin(clockMs / Duration.millisecondsPerSecond * 2).roundToDouble();

  /// 한 화면 프레임. [dtMs]는 실제 경과 시간.
  void update(double dtMs) {
    clockMs += dtMs;
    final rate = slowMoMs > 0 ? juice.bossSlowMoRate : 1.0;
    if (slowMoMs > 0) slowMoMs -= dtMs;
    player.advance(dtMs * rate);
    _updateStage();
    // 히트스톱 구간은 이펙트 시계도 멈춘다. 흔들림은 실제 시간으로 돈다.
    final fxDt = player.inHitStop ? 0.0 : dtMs * rate;
    updateProjectiles(this);
    for (final e in effects.active) {
      e.ageMs += fxDt;
      moveEffect(e);
    }
    effects.releaseWhere(_effectDone);
    zones.releaseWhere(_zoneDone);
    for (final c in coins.active) {
      c.ageMs += fxDt;
      moveCoin(c);
    }
    coins.releaseWhere(_coinDone);
    numbers.update(fxDt);
    shake.update(dtMs);
    for (var i = 0; i < kMaxSlots; i++) {
      slotFlashMs[i] = _down(slotFlashMs[i], dtMs);
    }
    shipFlashMs = _down(shipFlashMs, fxDt);
    shipHealMs = _down(shipHealMs, fxDt);
    shipBuffMs = _down(shipBuffMs, dtMs);
    screenFlashMs = _down(screenFlashMs, dtMs);
    bossWarnMs = _down(bossWarnMs, dtMs);
    bossFailMs = _down(bossFailMs, dtMs);
    backdrop.update(dtMs);
    moments.update(dtMs);
    applyHits(this, fxDt);
    _updateStats();
  }

  void _updateStage() {
    if (!player.isEmpty) moments.onFrame(frame);
  }

  static bool _effectDone(Effect e) => e.done;
  static bool _coinDone(Coin c) => c.done;
  // 장면 위치를 읽는 술어라 필드 클로저로 한 번만 만든다(프레임당 할당 0).
  // ignore: prefer_function_declarations_over_variables
  late final bool Function(Zone) _zoneDone = (z) => player.position >= z.endIndex;

  /// 이펙트 시트 한 번 재생. 상한을 넘으면 가장 오래된 것을 회수한다.
  /// [scale]배 크기, [delayMs] 뒤 시작, [durationMs]가 있으면 그 시간에 맞춰 프레임을 늘리고 [vx](px/ms)로 움직인다.
  Effect? spawnEffect(
    String sheetId,
    double x,
    double y, {
    double scale = 1,
    double delayMs = 0,
    double? durationMs,
    double vx = 0,
  }) {
    final sheet = fx.sheet(sheetId);
    if (sheet == null) return null;
    return effects.obtain()
      ..sheetId = sheetId
      ..x = x
      ..startX = x
      ..y = y
      ..w = sheet.w * scale
      ..h = sheet.h * scale
      ..frames = sheet.frames
      ..frameMs = durationMs == null ? fx.sheetFrameMs : durationMs / sheet.frames
      ..ageMs = 0
      ..delayMs = delayMs
      ..vx = vx
      ..color = fx.sheetColors[sheetId] ?? 0xFFFFFFFF;
  }

  /// 수중 장판을 [ticks] 동안 남긴다.
  void spawnZone(double x, double y, double radius, double ticks) {
    zones.obtain()
      ..x = x
      ..y = y
      ..radius = radius
      ..endIndex = player.position + ticks;
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
    zones.clear();
    shake.reset();
    slowMoMs = 0;
    screenFlashMs = 0;
    shipFlashMs = 0;
    shipHealMs = 0;
    shipBuffMs = 0;
    bossWarnMs = 0;
    bossFailMs = 0;
    moments.reset();
    combo.clear();
  }

  void _updateStats() {
    stats
      ..enemies = player.poseCount
      ..projectiles = projectiles.active.length
      ..effects = effects.active.length
      ..numbers = numbers.active.length
      ..coins = coins.active.length
      ..zones = zones.active.length
      ..pooledObjects =
          projectiles.created +
          effects.created +
          coins.created +
          numbers.pool.created +
          hits.created +
          zones.created +
          player.poses.length;
  }
}

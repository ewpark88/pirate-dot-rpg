import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/demo/sample_battle.g.dart';
import 'package:pirate_dot/render/demo/stress_recording.dart';
import 'package:pirate_dot/render/juice/juice_settings.dart';
import 'package:pirate_dot/render/paint/perf_overlay.dart';
import 'package:pirate_dot/render/paint/power_save_cache.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/perf/perf_monitor.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/viewport/integer_scale.dart';

export 'package:pirate_dot/render/juice/juice_settings.dart' show HapticLevel, JuiceSettings;
export 'package:pirate_dot/render/layout.dart' show kLogicalHeight, kLogicalWidth;

/// 전장이 무엇을 재생하는가.
enum BattleMode { live, demo, stress }

// 측정 스위치 (docs/specs/render-perf.md 규칙 5). 스토어 빌드에는 넣지 않는다.
const _sceneSwitch = String.fromEnvironment('BATTLE_SCENE');
const _perfOverlaySwitch = bool.fromEnvironment('PERF_OVERLAY');
const _powerSaveSwitch = bool.fromEnvironment('POWER_SAVE');

/// Flame 전장. 전투 기록(또는 엔진 라이브 입력)을 두 틱 사이로 보간해 그리고,
/// GameEvent를 보고 발사체·이펙트·데미지 숫자·흔들림을 만든다. 명령은 내지 않는다.
///
/// - `feed`가 있으면 라이브 모드: 엔진의 `EngineHost.ticks`를 구독한다 (`battleFeedProvider`).
/// - 없으면 `recording`(기본: 데모 기록 [sampleBattleJsonl])을 반복 재생한다.
/// - 운영자·측정: [loadStress]·[loadDemo]·[resumeLive], [perf]·[stats]·[showHitboxes]·[settings].
class BattleGame extends FlameGame {
  BattleGame({
    Stream<RecordedTick>? feed,
    this._recording,
    GameTables? tables,
    JuiceSettings settings = const JuiceSettings(),
    this.onHaptic,
    bool? perfOverlay,
    this.loadSprites = true,
    this.audio,
  }) : _feed = feed,
       _tables = tables ?? GameTables.load(),
       _settings = _powerSaveSwitch ? settings.copyWith(powerSave: true) : settings,
       perfOverlay = perfOverlay ?? _perfOverlaySwitch,
       super(camera: CameraComponent()) {
    _setMode(switch (_sceneSwitch) {
      'stress' => BattleMode.stress,
      'demo' => BattleMode.demo,
      _ => feed != null ? BattleMode.live : BattleMode.demo,
    });
  }

  final Stream<RecordedTick>? _feed;
  final List<RecordedTick>? _recording;
  final GameTables _tables;
  final void Function(HapticLevel level)? onHaptic;

  /// 측정 오버레이·10초 콘솔 요약.
  bool perfOverlay;

  /// 효과음·배경음 (flame_audio 어댑터). null이면 무음.
  final AudioPort? audio;

  /// 운영자 패널용 최근 효과음.
  List<String> get audioLog => scene.audioLog;

  /// onLoad에서 아트 팩(assets/)을 읽을지. 없는 이미지는 플레이스홀더.
  final bool loadSprites;
  SpriteBank? _sprites;
  bool _useSprites = true;

  /// 운영자 "스프라이트 끄기" (플레이스홀더와 비교).
  bool get useSprites => _useSprites;
  set useSprites(bool v) => painter.useSprites = _useSprites = v;

  /// 읽은 스프라이트 수 (0이면 전부 플레이스홀더).
  int get spriteCount => _sprites?.length ?? 0;

  late BattleScene scene;
  late ScenePainter painter;
  late BattleMode mode;
  StreamSubscription<RecordedTick>? _sub;

  final perf = PerfMonitor();
  final _overlay = PerfOverlay();
  final _cache = PowerSaveCache();

  /// 장면을 진행한 횟수 (절전 확인용).
  int sceneUpdates = 0;
  bool _dirty = true;
  double _powerSaveAccum = 0;
  double _summaryAccum = 0;
  bool _showHitboxes = false;
  // 메서드 tear-off는 프레임마다 클로저를 만든다 → 필드에 한 번만.
  // ignore: prefer_function_declarations_over_variables
  late final void Function(Canvas canvas) _paintScene = (c) => painter.paint(c);

  static const _sea = Color(0xFF1B4F72);
  static const _summaryEveryMs = 10000.0;

  /// 절전 주기 비교 허용 오차(ms) — 60Hz 두 프레임이 30Hz 한 주기와 부동소수로 딱 맞지 않을 때.
  static const _periodSlackMs = 0.5;

  double get fps => perf.fps;

  /// 측정 오버레이가 숫자를 갖고 있는가 (PERF_OVERLAY 확인용).
  bool get overlayReady => _overlay.hasText;
  SceneStats get stats => scene.stats;

  JuiceSettings _settings;
  JuiceSettings get settings => _settings;
  set settings(JuiceSettings v) {
    if (!v.powerSave) _cache.dispose();
    _settings = v;
    scene.settings = v;
  }

  /// 운영자 모드: 적 히트박스 표시.
  bool get showHitboxes => _showHitboxes;
  set showHitboxes(bool v) => painter.showHitboxes = _showHitboxes = v;

  void loadStress() => _setMode(BattleMode.stress);
  void loadDemo() => _setMode(BattleMode.demo);

  /// 라이브 입력으로 돌아간다. 입력이 없으면 데모.
  void resumeLive() => _setMode(_feed != null ? BattleMode.live : BattleMode.demo);

  void _setMode(BattleMode m) {
    final recording = switch (m) {
      BattleMode.live => null,
      BattleMode.stress => stressRecording(),
      BattleMode.demo => _recording ?? decodeRecording(sampleBattleJsonl),
    };
    mode = m;
    scene = BattleScene(_tables, recording, settings: _settings, onHaptic: onHaptic)..audio = audio;
    painter = ScenePainter(scene)
      ..showHitboxes = _showHitboxes
      ..sprites = _sprites
      ..useSprites = _useSprites;
    _cache.dispose();
    _dirty = true;
  }

  void _onTick(RecordedTick tick) {
    if (mode == BattleMode.live) scene.push(tick);
  }

  @override
  Color backgroundColor() => _sea;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.add(_SceneLayer(this));
    _sub = _feed?.listen(_onTick);
    if (loadSprites) {
      images.prefix = 'assets/';
      _sprites = await SpriteBank.load(images, _tables);
      painter.sprites = _sprites;
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final dpr = PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;
    final s = integerScale(size.x, size.y, dpr: dpr);
    camera.viewfinder
      ..zoom = s.scale
      ..position = Vector2(-s.offsetX / s.scale, -s.offsetY / s.scale);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final dtMs = dt * Duration.millisecondsPerSecond;
    perf.add(dtMs);
    if (perfOverlay) {
      _overlay.update(dtMs, perf, stats);
      _summaryAccum += dtMs;
      if (_summaryAccum >= _summaryEveryMs) {
        _summaryAccum = 0;
        debugPrint(perf.takeSummary(stats));
      }
    }
    var stepMs = dtMs;
    if (settings.powerSave) {
      // 절전: juice powerSave.fps 주기로만 장면을 진행하고, 그 사이 프레임은 직전 그림을 다시 그린다.
      _powerSaveAccum += dtMs;
      final period = Duration.millisecondsPerSecond / scene.juice.powerSaveFps;
      if (_powerSaveAccum + _periodSlackMs < period) return;
      stepMs = _powerSaveAccum;
      _powerSaveAccum = 0;
    }
    scene.update(stepMs);
    sceneUpdates++;
    _dirty = true;
  }

  void _renderScene(Canvas canvas) {
    if (settings.powerSave) {
      _cache.render(canvas, dirty: _dirty, paint: _paintScene);
    } else {
      painter.paint(canvas);
    }
    _dirty = false;
    if (perfOverlay) _overlay.paint(canvas);
  }

  @override
  void onRemove() {
    unawaited(_sub?.cancel());
    _sub = null;
    _cache.dispose();
    super.onRemove();
  }
}

/// 장면 전체를 한 컴포넌트로 그린다 (객체마다 컴포넌트를 만들지 않아 프레임당 생성이 없다).
class _SceneLayer extends Component {
  _SceneLayer(this.game);

  final BattleGame game;

  @override
  void render(Canvas canvas) => game._renderScene(canvas);
}

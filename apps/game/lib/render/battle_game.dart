import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/demo/sample_battle.g.dart';
import 'package:pirate_dot/render/juice/juice_settings.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

export 'package:pirate_dot/render/juice/juice_settings.dart' show HapticLevel, JuiceSettings;
export 'package:pirate_dot/render/layout.dart' show kLogicalHeight, kLogicalWidth;

/// Flame 전장. 전투 기록(또는 엔진 라이브 입력)을 두 틱 사이로 보간해 그리고,
/// GameEvent를 보고 발사체·이펙트·데미지 숫자·흔들림을 만든다. 명령은 내지 않는다.
///
/// - `feed`가 있으면 라이브 모드: 엔진의 `EngineHost.ticks`를 구독한다 (`battleFeedProvider`).
/// - 없으면 `recording`(기본: 데모 기록 [sampleBattleJsonl])을 반복 재생한다.
class BattleGame extends FlameGame {
  BattleGame({
    Stream<RecordedTick>? feed,
    List<RecordedTick>? recording,
    GameTables? tables,
    JuiceSettings settings = const JuiceSettings(),
    void Function(HapticLevel level)? onHaptic,
  }) : _feed = feed,
       scene = BattleScene(
         tables ?? GameTables.load(),
         feed != null ? null : recording ?? decodeRecording(sampleBattleJsonl),
         settings: settings,
         onHaptic: onHaptic,
       ),
       super(
         camera: CameraComponent.withFixedResolution(width: kLogicalWidth, height: kLogicalHeight),
       );

  final Stream<RecordedTick>? _feed;
  final BattleScene scene;
  late final ScenePainter painter = ScenePainter(scene);
  StreamSubscription<RecordedTick>? _sub;
  double _powerSaveAccum = 0;

  /// 운영자 모드에서 읽는 값: 화면 fps(지수 평균)와 장면 통계(`BattleScene.stats`).
  double fps = 0;
  SceneStats get stats => scene.stats;

  JuiceSettings get settings => scene.settings;
  set settings(JuiceSettings v) => scene.settings = v;

  /// 운영자 모드: 적 히트박스 표시.
  bool get showHitboxes => painter.showHitboxes;
  set showHitboxes(bool v) => painter.showHitboxes = v;

  static const _sea = Color(0xFF1B4F72);
  static const _fpsSmoothing = 0.1;

  @override
  Color backgroundColor() => _sea;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.add(_SceneLayer(painter));
    _sub = _feed?.listen(scene.push);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt > 0) fps += (1 / dt - fps) * _fpsSmoothing;
    var stepMs = dt * Duration.millisecondsPerSecond;
    if (settings.powerSave) {
      // 절전: juice powerSave.fps 주기로만 장면을 진행한다.
      _powerSaveAccum += stepMs;
      final period = Duration.millisecondsPerSecond / scene.juice.powerSaveFps;
      if (_powerSaveAccum < period) return;
      stepMs = _powerSaveAccum;
      _powerSaveAccum = 0;
    }
    scene.update(stepMs);
  }

  @override
  void onRemove() {
    unawaited(_sub?.cancel());
    _sub = null;
    super.onRemove();
  }
}

/// 장면 전체를 한 컴포넌트로 그린다 (객체마다 컴포넌트를 만들지 않아 프레임당 생성이 없다).
class _SceneLayer extends Component {
  _SceneLayer(this.painter);

  final ScenePainter painter;

  @override
  void render(Canvas canvas) => painter.paint(canvas);
}

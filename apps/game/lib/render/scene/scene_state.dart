/// 장면의 작은 상태 객체들 (battle_scene.dart에서 나눔).
library;

import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

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
  int zones = 0;

  /// 지금까지 본 분열·부활 연출 수 (M3 확인용).
  int splitPops = 0;
  int revives = 0;
  int shieldBreaks = 0;

  /// 풀·재사용 버퍼가 만든 객체 수. 워밍업 뒤에는 변하지 않아야 한다.
  int pooledObjects = 0;
}

/// 보물상자 그리기 상태 (BattleView.chest). [sink] 0(떠 있음)~1(다 가라앉음).
class ChestPose {
  bool visible = false;
  double x = 0;
  double y = 0;
  double sink = 0;

  /// 프레임의 상자 [c]로 갱신: 위아래로 둥둥, 남은 틱이 `sinkTicks`보다 적으면 가라앉는다.
  void update(ChestView? c, JsonReader cfg, double clockMs) {
    visible = c != null;
    if (c == null) return;
    final sinkTicks = cfg.number('sinkTicks');
    sink = c.ticksLeft >= sinkTicks ? 0 : 1 - c.ticksLeft / sinkTicks;
    x = c.x;
    y = c.y + cfg.number('bobPx') * math.sin(clockMs / cfg.number('bobMs') * 2 * math.pi) + cfg.number('sinkPx') * sink;
  }
}

/// 처치 연쇄(피드백 #4 핵앤슬래시): 직전 처치에서 [windowMs] 안에 다음 처치가 오면 이어지고, 끊기면 0부터.
/// 화면에는 마지막 처치 뒤 [windowMs] × 1.5까지 남는다. 할당 없음.
class ComboTracker {
  ComboTracker({required this.windowMs});

  final double windowMs;
  int _count = 0;
  double _last = double.negativeInfinity;

  /// 마지막으로 늘어난 시각(배너 '쿵' 확대용).
  double get lastAddMs => _last;

  void add(double clockMs) {
    _count = clockMs - _last <= windowMs ? _count + 1 : 1;
    _last = clockMs;
  }

  /// [nowMs]에서 보이는 연쇄 수 (끊긴 지 오래면 0).
  int count(double nowMs) => nowMs - _last <= windowMs * 1.5 ? _count : 0;

  void clear() {
    _count = 0;
    _last = double.negativeInfinity;
  }
}

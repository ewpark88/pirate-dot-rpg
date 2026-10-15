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

/// 최근 처치 시각 고리 버퍼 — `xN COMBO` 배너(render-quality-v1 규칙 5). 할당 없이 [capacity]개까지 기억.
class ComboTracker {
  ComboTracker({required this.windowMs, this.capacity = 64})
    : _times = List<double>.filled(capacity, double.negativeInfinity);

  final double windowMs;
  final int capacity;
  final List<double> _times;
  int _next = 0;

  void add(double clockMs) {
    _times[_next] = clockMs;
    _next = (_next + 1) % capacity;
  }

  /// [nowMs]에서 [windowMs] 안에 들어온 처치 수.
  int count(double nowMs) {
    var n = 0;
    for (final t in _times) {
      if (nowMs - t < windowMs) n++;
    }
    return n;
  }

  void clear() => _times.fillRange(0, capacity, double.negativeInfinity);
}

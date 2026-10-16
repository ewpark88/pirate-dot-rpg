import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// 방치 단계 (사용자: S24 10분 만에 45℃ — 방치 중엔 덜 그린다, OLED 잔상 걱정).
/// - [active]: 평소.
/// - [idle]: 입력 없이 fx_map frameCap.idleSec(60초) — 절전 그리기(30fps·가벼운 연출·흔들림 끔).
/// - [dim]: frameCap.dimSec(3분) — 전장을 아주 어둡게, 배·적 점만 frameCap.dimFps로. UI 덮개는 S4가 [IdleWatch.level]을 보고.
enum IdleLevel { active, idle, dim }

/// 마지막 입력(화면 어디든 포인터)부터 지난 시간으로 방치 단계를 정한다. 입력이 오면 바로 [IdleLevel.active].
class IdleWatch {
  IdleWatch({required this.idleMs, required this.dimMs, required this.now});

  final double idleMs;
  final double dimMs;

  /// 지금 시각(ms) — 앱은 Stopwatch, 테스트는 가짜 시계.
  final double Function() now;

  final ValueNotifier<IdleLevel> level = ValueNotifier(IdleLevel.active);
  double _lastInput = 0;
  bool _routed = false;

  /// 화면 전체 포인터를 듣는다(위젯 트리 밖 전역 경로 — UI 레인을 건드리지 않는다).
  void attach() {
    if (_routed) return;
    _routed = true;
    _lastInput = now();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  void detach() {
    if (!_routed) return;
    _routed = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
  }

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent || e is PointerMoveEvent || e is PointerScrollEvent) input();
  }

  /// 입력이 있었다(테스트·UI가 직접 불러도 된다).
  void input() {
    _lastInput = now();
    level.value = IdleLevel.active;
  }

  /// 프레임마다: 지난 시간으로 단계를 갱신한다.
  void tick() {
    final quiet = now() - _lastInput;
    level.value = quiet >= dimMs ? IdleLevel.dim : (quiet >= idleMs ? IdleLevel.idle : IdleLevel.active);
  }
}

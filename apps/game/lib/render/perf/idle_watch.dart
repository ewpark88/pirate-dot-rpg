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

  /// 어두운 절전 화면까지(ms). 0 이하면 끔 — 사용자 설정 sleepAfterSec(S2)을 BattleGame.sleepAfterSec이 넣는다.
  double dimMs;

  /// 지금 시각(ms) — 앱은 Stopwatch, 테스트는 가짜 시계.
  final double Function() now;

  final ValueNotifier<IdleLevel> level = ValueNotifier(IdleLevel.active);

  /// 기기 발열 단계 0 none·1 light·2 moderate·3 severe·4 critical (UI가 thermalLevelProvider의 index를 넣는다).
  /// 보통(2) 이상이면 방치처럼 가벼운 그리기, 심함(3) 이상이면 효과음 예산도 줄인다.
  final ValueNotifier<int> heat = ValueNotifier(0);

  /// 가벼운 그리기(30fps·가벼운 연출·흔들림 끔)를 써야 하나 — 방치 또는 발열 보통 이상.
  bool get lite => level.value != IdleLevel.active || heat.value >= 2;

  /// 효과음 초당 예산 배율 — 방치 단계와 발열 중 더 낮은 쪽.
  double get soundBudget {
    final byIdle = switch (level.value) {
      IdleLevel.active => 1.0,
      IdleLevel.idle => 0.5,
      IdleLevel.dim => 0.15,
    };
    final byHeat = heat.value >= 3 ? 0.5 : 1.0;
    return byIdle < byHeat ? byIdle : byHeat;
  }

  double _lastInput = 0;
  bool _routed = false;

  /// 화면 전체 포인터를 듣는다(위젯 트리 밖 전역 경로 — UI 레인을 건드리지 않는다).
  void attach() {
    if (_routed || _following) return;
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
    if (_following) return;
    _lastInput = now();
    level.value = IdleLevel.active;
  }

  /// UI가 원본(S1 결정 — 앱 루트 idleLevelProvider, 모든 터치): 받은 단계를 그대로 쓰고 스스로 세지 않는다.
  bool get following => _following;
  bool _following = false;

  void follow(IdleLevel l) {
    if (!_following) {
      _following = true;
      detach();
    }
    level.value = l;
  }

  /// 프레임마다: 지난 시간으로 단계를 갱신한다(UI를 따를 때는 아무것도 안 함).
  void tick() {
    if (_following) return;
    final quiet = now() - _lastInput;
    level.value = dimMs > 0 && quiet >= dimMs ? IdleLevel.dim : (quiet >= idleMs ? IdleLevel.idle : IdleLevel.active);
  }
}

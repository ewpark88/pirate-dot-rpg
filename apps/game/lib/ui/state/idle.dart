import 'package:flutter_riverpod/flutter_riverpod.dart';

// 방치 단계 (사용자 지시 2026-10-16 발열·배터리·OLED 잔상 대책, S1): 렌더·오디오도 이 값을 본다.
// active = 입력 있음 · idle = 60초 입력 없음(렌더가 효과를 줄일 수 있다) · sleep = 절전 화면(기본 3분).

enum IdleLevel { active, idle, sleep }

/// 입력이 없을 때 idle이 되는 시간.
const idleAfter = Duration(seconds: 60);

/// 절전 화면까지 기본 시간 (설정 sleepAfterSec 기본 180과 같다).
const sleepAfterDefault = Duration(minutes: 3);

/// 설정 → 절전 화면까지 시간. 절전 모드 끔 또는 0초면 null(절전 화면 없음).
Duration? sleepAfterOf({required bool powerSave, required int sec}) =>
    powerSave && sec > 0 ? Duration(seconds: sec) : null;

/// 지금 방치 단계 (공용). [IdleNotifier.touch]가 입력마다 active로 되돌린다.
final idleLevelProvider = NotifierProvider<IdleNotifier, IdleLevel>(IdleNotifier.new);

class IdleNotifier extends Notifier<IdleLevel> {
  DateTime _lastInput = DateTime.now();

  @override
  IdleLevel build() => IdleLevel.active;

  /// 마지막 입력 시각.
  DateTime get lastInput => _lastInput;

  /// 입력 한 번 (터치·키).
  void touch(DateTime now) {
    _lastInput = now;
    if (state != IdleLevel.active) state = IdleLevel.active;
  }

  /// 시각 [now]에서 단계를 다시 고른다. [sleepAfter] null이면 절전 화면 끔.
  void evaluate(DateTime now, {Duration? sleepAfter = sleepAfterDefault}) {
    final quiet = now.difference(_lastInput);
    final next = sleepAfter != null && quiet >= sleepAfter
        ? IdleLevel.sleep
        : (quiet >= idleAfter ? IdleLevel.idle : IdleLevel.active);
    if (next != state) state = next;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart' show Settings;

// 방치 단계 (사용자 지시 2026-10-16 발열·배터리·OLED 잔상 대책, S1): 렌더·오디오도 이 값을 본다.
// active = 입력 있음 · idle = 60초 입력 없음(렌더가 효과를 줄일 수 있다) · sleep = 절전 화면(기본 3분).

enum IdleLevel { active, idle, sleep }

/// 입력이 없을 때 idle이 되는 시간.
const idleAfter = Duration(seconds: 60);

/// 절전 화면까지 기본 시간 (설정 기본값 Settings.defaultSleepAfterSec — 10분).
const sleepAfterDefault = Duration(seconds: Settings.defaultSleepAfterSec);

/// 절전 화면까지 고를 수 있는 시간(초) — 사용자 '3분은 너무 빠르다' → 1·5·10·20·30분(기본 10분, 끔 없음 — 끄려면 절전 모드를 끈다).
const sleepAfterChoices = [60, 300, 600, 1200, 1800];

/// 저장된 값 → 가장 가까운 선택지, 같으면 긴 쪽 (옛 세이브 180 → 5분, 0 → 1분).
int nearestSleepChoice(int sec) => sleepAfterChoices.reduce((a, b) => (a - sec).abs() < (b - sec).abs() ? a : b);

/// 설정 → 절전 화면까지 시간. 절전 모드 끔이면 null(절전 화면 없음).
Duration? sleepAfterOf({required bool powerSave, required int sec}) =>
    powerSave ? Duration(seconds: nearestSleepChoice(sec)) : null;

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

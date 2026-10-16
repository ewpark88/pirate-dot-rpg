import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/state/idle.dart';

// 발열 대책(사용자 실기기 2026-10-17 S24: 10분에 배터리 45℃·발열 SEVERE, CPU 184% + 오디오 56%, 120Hz — S1).
// Android 쪽은 MainActivity.kt(pirate_dot/power·pirate_dot/thermal).

/// 기기 발열 단계(PowerManager.THERMAL_STATUS_*). 렌더·오디오가 본다.
enum ThermalLevel { none, light, moderate, severe, critical }

/// Android 값(0 없음 1 가벼움 2 보통 3 심함 4 위험 5 비상 6 꺼짐) → 단계(4 이상은 critical).
ThermalLevel thermalFrom(int status) => ThermalLevel.values[status.clamp(0, ThermalLevel.values.length - 1)];

/// 지금 발열 단계(공용, 기본 none — 플랫폼이 알려 주면 바뀜).
final thermalLevelProvider = NotifierProvider<ThermalNotifier, ThermalLevel>(ThermalNotifier.new);

class ThermalNotifier extends Notifier<ThermalLevel> {
  @override
  ThermalLevel build() => ThermalLevel.none;

  void set(ThermalLevel level) {
    if (level != state) state = level;
  }
}

/// 화면 주사율 정책: 기본 60Hz(120Hz 기기도), 방치·절전 화면이거나 발열 보통 이상이면 30Hz.
int targetFrameRate({required IdleLevel idle, required ThermalLevel thermal}) =>
    idle != IdleLevel.active || thermal.index >= ThermalLevel.moderate.index ? 30 : 60;

/// 효과음 끄기 정책: 방치·절전 화면이거나 발열 심함 이상이면 효과음 끔(배경음만).
bool sfxQuiet({required IdleLevel idle, required ThermalLevel thermal}) =>
    idle != IdleLevel.active || thermal.index >= ThermalLevel.severe.index;

/// 플랫폼 채널. 플러그인이 없는 곳(테스트·데스크톱)에서는 조용히 아무것도 하지 않는다.
class PowerChannel {
  static const _method = MethodChannel('pirate_dot/power');
  static const _events = EventChannel('pirate_dot/thermal');

  int? _rate;

  /// 같은 값이면 다시 보내지 않는다.
  Future<void> setFrameRate(int hz) async {
    if (_rate == hz) return;
    _rate = hz;
    try {
      await _method.invokeMethod<void>('setFrameRate', hz);
      debugPrint('power: frame rate $hz');
    } on Object catch (e) {
      debugPrint('power: setFrameRate failed ($e)');
    }
  }

  Future<ThermalLevel> thermal() async {
    try {
      return thermalFrom(await _method.invokeMethod<int>('thermalStatus') ?? 0);
    } on Object {
      return ThermalLevel.none;
    }
  }

  /// FLAG_KEEP_SCREEN_ON이 걸려 있나(확인용 — 우리 앱은 걸지 않는다).
  Future<bool> keepScreenOn() async {
    try {
      return await _method.invokeMethod<bool>('keepScreenOn') ?? false;
    } on Object {
      return false;
    }
  }

  Stream<ThermalLevel> get changes =>
      _events.receiveBroadcastStream().map((s) => thermalFrom(s as int)).handleError((Object e) {
        debugPrint('power: thermal stream failed ($e)');
      });
}

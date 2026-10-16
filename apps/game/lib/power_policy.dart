import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/adapters/power/power_channel.dart';
import 'package:pirate_dot/ui/state/idle.dart';

// 발열 대책 정책(실기기 S24 2026-10-17) — main이 방치 단계·발열 단계를 보고 주사율·효과음을 정한다(PowerChannel·AudioAdapter).

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

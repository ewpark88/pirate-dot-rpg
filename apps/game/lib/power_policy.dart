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

/// 효과음 끄기 정책: **절전 화면(어두운 덮개)일 때만** 끈다(배경음만).
/// 사용자 폰 버그(2026-10-17 '보스전이든 아니든 가끔 타격 소리가 안 나고 배경음악만'): 예전엔 방치(입력 없이 60초)에도 껐다 —
/// 보면서 두는 게임이라 화면을 안 만지는 동안 타격음이 사라졌다. 발열이 심해도 끄지 않고 동시 수를 줄인다([sfxMaxTotal]).
bool sfxQuiet({required IdleLevel idle, required ThermalLevel thermal}) => idle == IdleLevel.sleep;

/// 효과음 동시 재생 상한: 보통 AudioAdapter.maxTotalSfx, 발열 심함 이상이면 그 3분의 1(오디오 CPU 줄이기 — 소리는 남긴다).
int sfxMaxTotal({required ThermalLevel thermal, required int normal}) =>
    thermal.index >= ThermalLevel.severe.index ? (normal / 3).ceil() : normal;

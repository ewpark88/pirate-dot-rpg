import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/adapters/power/power_channel.dart';
import 'package:pirate_dot/power_policy.dart';
import 'package:pirate_dot/ui/state/idle.dart';

/// 발열 대책 정책(실기기 S24 2026-10-17 — 120Hz·45℃·SEVERE).
void main() {
  test('주사율: 평소 60Hz, 방치·절전 화면·발열 보통 이상이면 30Hz', () {
    expect(targetFrameRate(idle: IdleLevel.active, thermal: ThermalLevel.none), 60);
    expect(targetFrameRate(idle: IdleLevel.active, thermal: ThermalLevel.light), 60);
    expect(targetFrameRate(idle: IdleLevel.idle, thermal: ThermalLevel.none), 30);
    expect(targetFrameRate(idle: IdleLevel.sleep, thermal: ThermalLevel.none), 30);
    expect(targetFrameRate(idle: IdleLevel.active, thermal: ThermalLevel.moderate), 30);
  });

  test('효과음: 방치·절전·발열 심함 이상이면 끔(배경음만)', () {
    expect(sfxQuiet(idle: IdleLevel.active, thermal: ThermalLevel.moderate), isFalse);
    expect(sfxQuiet(idle: IdleLevel.idle, thermal: ThermalLevel.none), isTrue);
    expect(sfxQuiet(idle: IdleLevel.active, thermal: ThermalLevel.severe), isTrue);
  });

  test('Android 발열 값 → 단계(4 이상은 위험)', () {
    expect(thermalFrom(0), ThermalLevel.none);
    expect(thermalFrom(2), ThermalLevel.moderate);
    expect(thermalFrom(3), ThermalLevel.severe);
    expect(thermalFrom(6), ThermalLevel.critical);
  });

  test('플러그인이 없으면(테스트·데스크톱) 조용히 넘어간다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final p = PowerChannel();
    await p.setFrameRate(60);
    expect(await p.thermal(), ThermalLevel.none);
    expect(await p.keepScreenOn(), isFalse);
  });
}

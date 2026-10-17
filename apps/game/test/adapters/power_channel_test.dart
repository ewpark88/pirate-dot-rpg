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

  test('효과음: 절전 화면일 때만 끔 — 방치(60초 무입력)·발열 심함엔 켜 둔다(사용자 폰 버그 회귀 방지)', () {
    expect(sfxQuiet(idle: IdleLevel.active, thermal: ThermalLevel.moderate), isFalse);
    expect(
      sfxQuiet(idle: IdleLevel.idle, thermal: ThermalLevel.none),
      isFalse,
      reason: '보면서 두는 게임 — 안 만져도 타격음',
    );
    expect(sfxQuiet(idle: IdleLevel.active, thermal: ThermalLevel.severe), isFalse);
    expect(sfxQuiet(idle: IdleLevel.sleep, thermal: ThermalLevel.none), isTrue);
  });

  test('발열 심함 이상이면 효과음 동시 수만 줄인다(끄지 않음)', () {
    expect(sfxMaxTotal(thermal: ThermalLevel.moderate, normal: 6), 6);
    expect(sfxMaxTotal(thermal: ThermalLevel.severe, normal: 6), 2);
    expect(sfxMaxTotal(thermal: ThermalLevel.critical, normal: 6), greaterThanOrEqualTo(1));
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

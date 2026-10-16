import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

/// 설정 flashLevel(사용자 '번쩍임 눈 아프다')·sleepAfterSec(절전 화면) — S4 요청, 세이브 이행.
void main() {
  Json oldSave({required bool flash}) => {
    ...const Settings().toJson(),
    'flash': flash,
  }..remove('flashLevel');

  test('옛 세이브(flash bool만): 켬 → soft, 끔 → off, 절전 기본 180초', () {
    expect(Settings.fromJson(oldSave(flash: true)).flashLevel, 'soft');
    expect(Settings.fromJson(oldSave(flash: false)).flashLevel, 'off');
    expect(Settings.fromJson(oldSave(flash: true)).sleepAfterSec, Settings.defaultSleepAfterSec);
    expect(Settings.defaultSleepAfterSec, 180);
  });

  test('기본값이면 본문이 옛 세이브와 같다(새 키를 쓰지 않음), 바꾸면 쓰고 되읽는다', () {
    expect(const Settings().toJson().keys, isNot(contains('flashLevel')));
    expect(const Settings().toJson().keys, isNot(contains('sleepAfterSec')));
    final s = const Settings().withValue('flashLevel', 'full').withValue('sleepAfterSec', 0);
    final back = Settings.fromJson(s.toJson());
    expect(back.flashLevel, 'full');
    expect(back.flash, isTrue);
    expect(back.sleepAfterSec, 0);
  });

  test('번쩍임 둘은 함께 움직인다: 세기 off ↔ flash false, flash true → soft', () {
    final off = const Settings().withValue('flashLevel', 'off');
    expect(off.flash, isFalse);
    expect(off.withValue('flash', true).flashLevel, 'soft');
    expect(const Settings().withValue('flash', false).flashLevel, 'off');
  });

  test('SetSetting 명령으로 바꾸고, 틀린 값은 거절한다', () {
    final cmd = Command.fromJson(const {'type': 'setSetting', 'key': 'flashLevel', 'value': 'soft'});
    expect(cmd, isA<SetSetting>());
    expect(() => const Settings().withValue('flashLevel', 'bright'), throwsArgumentError);
    expect(() => const Settings().withValue('sleepAfterSec', -1), throwsArgumentError);
    expect(() => const Settings().withValue('sleepAfterSec', '60'), throwsArgumentError);
  });
}

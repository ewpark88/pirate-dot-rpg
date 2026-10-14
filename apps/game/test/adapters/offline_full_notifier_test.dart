import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/testing.dart';
import 'package:pirate_dot/adapters/notify/notify_sdk.dart';
import 'package:pirate_dot/adapters/notify/notify_texts.dart';
import 'package:pirate_dot/adapters/notify/offline_full_notifier.dart';

class FakeNotifySdk implements NotifySdk {
  final scheduled = <int, DateTime>{};
  final titles = <String>[];
  int permissionRequests = 0;

  @override
  Future<void> schedule({required int id, required DateTime at, required NotifyTexts texts}) async {
    scheduled[id] = at;
    titles.add(texts.title);
  }

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }
}

void main() {
  late Directory dir;
  late FakeNotifySdk sdk;
  late ManualClock clock;
  var enabled = true;
  var lang = 'ko';

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pde_notify_');
    sdk = FakeNotifySdk();
    clock = ManualClock(DateTime.utc(2026, 11, 1, 9));
    enabled = true;
    lang = 'ko';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  // 날짜 판정은 현지 시각 — 테스트는 UTC를 현지로 본다(결정론).
  OfflineFullNotifier make() => OfflineFullNotifier(
    sdk: sdk,
    clock: clock,
    dir: dir,
    fullAfter: const Duration(seconds: 28800),
    minAway: const Duration(seconds: 60),
    dailyMax: 1,
    enabled: () => enabled,
    lang: () => lang,
    toLocal: (t) => t,
  );

  test('9. 켜짐·오늘 기록 없음 → pause 때 8시간 뒤 1건', () async {
    await make().onPause();
    expect(sdk.scheduled.values, [DateTime.utc(2026, 11, 1, 17)]);
  });

  test('10. 울릴 날짜에 이미 기록이 있으면 예약 안 함, 다음 날짜면 예약', () async {
    final n = make();
    await n.onPause(); // 17시에 울림 → 그대로 울렸다고 치자
    clock.setTime(DateTime.utc(2026, 11, 1, 18));
    await n.onResume();
    sdk.scheduled.clear();
    clock.setTime(DateTime.utc(2026, 11, 1, 19)); // 울릴 시각 11/2 03시 → 다른 날짜
    await n.onPause();
    expect(sdk.scheduled.values, [DateTime.utc(2026, 11, 2, 3)]);
    sdk.scheduled.clear();
    clock.setTime(DateTime.utc(2026, 11, 1, 20));
    await n.onResume(); // 아직 안 울린 예약은 취소 → 기록에서도 빠진다
    await n.onPause(); // 11/2 04시 → 11/2 기록 없음
    expect(sdk.scheduled.length, 1);
    clock.setTime(DateTime.utc(2026, 11, 2, 5));
    await n.onResume(); // 04시에 울렸음
    clock.setTime(DateTime.utc(2026, 11, 1, 21));
    sdk.scheduled.clear();
    await make().onPause(); // 새 인스턴스도 파일 기록을 본다 — 11/2 05시는 이미 1회
    expect(sdk.scheduled, isEmpty);
  });

  test('11. resume이면 예약 취소', () async {
    final n = make();
    await n.onPause();
    clock.setTime(DateTime.utc(2026, 11, 1, 10));
    await n.onResume();
    expect(sdk.scheduled, isEmpty);
  });

  test('12. 설정 꺼짐이면 예약 없음 + 남은 예약 취소', () async {
    final n = make();
    await n.onPause();
    enabled = false;
    await n.onSettingChanged(enabled: false);
    expect(sdk.scheduled, isEmpty);
    await n.onPause();
    expect(sdk.scheduled, isEmpty);
  });

  test('13. lang=en이면 영어 문구', () async {
    lang = 'en';
    await make().onPause();
    expect(sdk.titles, ['Your treasure hold is full!']);
    expect(notifyTextsFor('ko').title, '보물창고가 가득 찼어요!');
  });

  test('14. 60초 이상 비운 첫 복귀에 권한 1회, 다시 안 묻는다', () async {
    final n = make();
    await n.onPause();
    clock.advance(const Duration(seconds: 30));
    await n.onResume();
    expect(sdk.permissionRequests, 0);
    await n.onPause();
    clock.advance(const Duration(seconds: 61));
    await n.onResume();
    expect(sdk.permissionRequests, 1);
    await n.onPause();
    clock.advance(const Duration(minutes: 5));
    await make().onResume();
    expect(sdk.permissionRequests, 1);
  });

  test('깨진 기록 파일은 빈 기록으로', () async {
    File('${dir.path}/notify.json').writeAsStringSync('{깨짐');
    await make().onPause();
    expect(sdk.scheduled.length, 1);
  });
}

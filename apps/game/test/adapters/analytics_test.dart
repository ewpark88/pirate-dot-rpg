import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/adapters/analytics/analytics_sdk.dart';
import 'package:pirate_dot/adapters/analytics/noop_analytics.dart';
import 'package:pirate_dot/adapters/analytics/sdk_analytics.dart';

class FakeAnalyticsSdk implements AnalyticsSdk {
  final events = <String, Map<String, Object>>{};
  final props = <String, String>{};
  final crashKeys = <String, Object>{};
  bool? collection;

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async => events[name] = params;

  @override
  Future<void> setUserProperty(String name, String value) async => props[name] = value;

  @override
  Future<void> setCrashKey(String key, Object value) async => crashKeys[key] = value;

  @override
  Future<void> setCollection({required bool enabled}) async => collection = enabled;

  final nonFatal = <String>[];

  @override
  Future<void> recordNonFatal(Object error, StackTrace? stack, {required String reason}) async => nonFatal.add(reason);
}

void main() {
  test('15. 초기화 실패(설정 파일 없음)면 NoopAnalytics, 호출은 조용히 무시', () async {
    final a = await startAnalytics(() async => throw StateError('no google-services.json'));
    expect(a, isA<NoopAnalytics>());
    a
      ..log('stage_clear', {'stage': 3})
      ..setLastSeen(screen: 'ship', stage: 3)
      ..setCollection(enabled: true);
  });

  test('16. setLastSeen → 사용자 속성 2개 + Crashlytics 키 2개 + screen_view', () async {
    final sdk = FakeAnalyticsSdk();
    final a = await startAnalytics(() async => sdk);
    a.setLastSeen(screen: 'ship', stage: 12);
    await pumpEventQueue();
    expect(sdk.props, {'last_screen': 'ship', 'last_stage': '12'});
    expect(sdk.crashKeys, {'screen': 'ship', 'stage': 12});
    expect(sdk.events['screen_view'], {'screen_name': 'ship'});
  });

  test('17. 이벤트 이름 규칙 위반은 SDK에 안 간다', () async {
    final sdk = FakeAnalyticsSdk();
    final a = await startAnalytics(() async => sdk);
    a
      ..log('has space')
      ..log('a' * 41)
      ..log('1starts_with_digit')
      ..log('firebase_reserved')
      ..log('boss_fail', {'stage': 25});
    await pumpEventQueue();
    expect(sdk.events.keys, ['boss_fail']);
  });

  test('수집 켜기/끄기는 UMP 동의에 묶는다', () async {
    final sdk = FakeAnalyticsSdk();
    final a = await startAnalytics(() async => sdk);
    a.setCollection(enabled: false);
    await pumpEventQueue();
    expect(sdk.collection, isFalse);
  });
}

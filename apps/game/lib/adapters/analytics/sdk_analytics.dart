import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pirate_dot/adapters/analytics/analytics_sdk.dart';
import 'package:pirate_dot/adapters/analytics/noop_analytics.dart';

/// SDK를 띄워 본다. 실패(= `google-services.json` 없음 등)하면 [NoopAnalytics] — 앱 시작을 막지 않는다.
Future<AppAnalytics> startAnalytics(Future<AnalyticsSdk> Function() init) async {
  try {
    return SdkAnalytics(await init());
  } on Object catch (e) {
    debugPrint('analytics: off ($e)');
    return const NoopAnalytics();
  }
}

/// [AnalyticsSdk] 위의 분석 포트 (스펙 platform-m4 c). 호출은 기다리지 않고 실패는 삼킨다.
class SdkAnalytics implements AppAnalytics {
  SdkAnalytics(this._sdk);

  final AnalyticsSdk _sdk;

  /// Firebase 이벤트 이름: 글자로 시작, 영숫자·밑줄, 40자 이하, 예약 접두어 금지.
  static final _name = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');
  static const _reserved = ['firebase_', 'google_', 'ga_'];

  static bool validName(String n) => _name.hasMatch(n) && !_reserved.any(n.startsWith);

  @override
  void log(String event, [Map<String, Object> params = const {}]) {
    if (!validName(event)) {
      debugPrint('analytics: invalid event name "$event" — ignored');
      return;
    }
    _fire(_sdk.logEvent(event, params));
  }

  @override
  void setLastSeen({required String screen, required int stage}) {
    _fire(_sdk.setUserProperty('last_screen', screen));
    _fire(_sdk.setUserProperty('last_stage', '$stage'));
    _fire(_sdk.setCrashKey('screen', screen));
    _fire(_sdk.setCrashKey('stage', stage));
    _fire(_sdk.logEvent('screen_view', {'screen_name': screen}));
  }

  @override
  void setCollection({required bool enabled}) => _fire(_sdk.setCollection(enabled: enabled));

  static void _fire(Future<void> f) => unawaited(f.catchError((Object e) => debugPrint('analytics: $e')));
}

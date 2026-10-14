import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:pirate_dot/adapters/analytics/analytics_sdk.dart';

/// Firebase를 띄운다. `google-services.json`이 없으면 `initializeApp`이 던진다 → `startAnalytics`가 Noop으로 바꾼다.
/// [collectCrashes]: 배포 빌드에서만 true (디버그·운영자 빌드는 수집 안 함). iOS는 M6까지 시작하지 않는다.
/// Analytics 수집은 꺼진 채로 시작하고, UMP 동의가 나면 `setCollection(enabled: true)`로 켠다.
Future<AnalyticsSdk> initFirebase({required bool collectCrashes}) async {
  if (!Platform.isAndroid) throw UnsupportedError('Firebase: Android only until M6');
  await Firebase.initializeApp();
  final crash = FirebaseCrashlytics.instance;
  await crash.setCrashlyticsCollectionEnabled(collectCrashes);
  if (collectCrashes) {
    FlutterError.onError = crash.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (e, s) {
      unawaited(crash.recordError(e, s, fatal: true));
      return true;
    };
  }
  final analytics = FirebaseAnalytics.instance;
  await analytics.setAnalyticsCollectionEnabled(false);
  return FirebaseAnalyticsSdk(analytics, crash);
}

class FirebaseAnalyticsSdk implements AnalyticsSdk {
  FirebaseAnalyticsSdk(this._analytics, this._crash);

  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crash;

  @override
  Future<void> logEvent(String name, Map<String, Object> params) => _analytics.logEvent(name: name, parameters: params);

  @override
  Future<void> setUserProperty(String name, String value) => _analytics.setUserProperty(name: name, value: value);

  @override
  Future<void> setCrashKey(String key, Object value) => _crash.setCustomKey(key, value);

  @override
  Future<void> setCollection({required bool enabled}) => _analytics.setAnalyticsCollectionEnabled(enabled);
}

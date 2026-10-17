import 'package:game_core/contracts.dart';

/// Firebase Analytics + Crashlytics를 감싼 얇은 경계. 실제 구현은 `firebase_sdk.dart`, 테스트는 가짜.
abstract interface class AnalyticsSdk {
  Future<void> logEvent(String name, Map<String, Object> params);

  Future<void> setUserProperty(String name, String value);

  /// Crashlytics 커스텀 키 (충돌 보고서에 붙는다).
  Future<void> setCrashKey(String key, Object value);

  /// 비치명 오류 보고(Crashlytics recordError fatal: false) — [reason]은 보고서 이유 줄.
  Future<void> recordNonFatal(Object error, StackTrace? stack, {required String reason});

  /// Analytics 수집 켜기/끄기 — UMP 동의에 묶는다(스펙 결정 ②).
  Future<void> setCollection({required bool enabled});
}

/// 앱이 쓰는 분석 포트 + 동의 연결.
abstract interface class AppAnalytics implements AnalyticsPort {
  void setCollection({required bool enabled});

  /// Crashlytics 커스텀 키(충돌 보고서 맥락 — S4 CrashContextGate가 장면·피버·적 수 등을 바뀔 때만 건다).
  void setCrashKey(String key, Object value);
}

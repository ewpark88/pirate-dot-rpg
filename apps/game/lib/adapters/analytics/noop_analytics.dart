import 'package:pirate_dot/adapters/analytics/analytics_sdk.dart';

/// 분석 없음. Firebase 설정 파일이 없거나 초기화에 실패했을 때, UI provider의 기본값.
class NoopAnalytics implements AppAnalytics {
  const NoopAnalytics();

  @override
  void log(String event, [Map<String, Object> params = const {}]) {}

  @override
  void setLastSeen({required String screen, required int stage}) {}

  @override
  void setCollection({required bool enabled}) {}
}

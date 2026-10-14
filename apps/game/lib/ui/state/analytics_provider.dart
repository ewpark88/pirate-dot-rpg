import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

/// 아무것도 보내지 않는 분석 포트 (기본값).
// TODO(platform): S5의 NoopAnalytics(adapters/)가 main에 오면 그것으로 바꾸고 이 클래스는 지운다.
class NoopAnalytics implements AnalyticsPort {
  const NoopAnalytics();

  @override
  void log(String event, [Map<String, Object> params = const {}]) {}

  @override
  void setLastSeen({required String screen, required int stage}) {}
}

/// 이탈 분석 포트 (설계서 4.9: 마지막 화면·스테이지). 앱·platform 레인이 실제 어댑터로 덮는다.
final analyticsPortProvider = Provider<AnalyticsPort>((_) => const NoopAnalytics());

/// 탭 순서대로 분석에 남기는 화면 id (탭 4개 고정).
const analyticsTabIds = ['voyage', 'ship', 'crew', 'summon'];

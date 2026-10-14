import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/analytics/noop_analytics.dart';

/// 이탈 분석 포트 (설계서 4.9: 마지막 화면·스테이지). 앱·platform 레인이 실제 어댑터로 덮는다.
final analyticsPortProvider = Provider<AnalyticsPort>((_) => const NoopAnalytics());

/// 탭 순서대로 분석에 남기는 화면 id (탭 4개 고정).
const analyticsTabIds = ['voyage', 'ship', 'crew', 'summon'];

import 'package:game_core/game_core.dart';

/// 엔진 이벤트 → 분석 이벤트 (현상금 사냥 B5, 계획 docs/plans/active/platform-bounty-topdown.md).
/// EngineHost.ticks의 이벤트를 받아 필요한 것만 [AnalyticsPort.log]로 보낸다. 다른 이벤트는 무시한다.
void logGameEvents(AnalyticsPort analytics, Iterable<GameEvent> events) {
  for (final e in events) {
    switch (e) {
      case BountyStarted(:final bossId, :final tier):
        analytics.log('bounty_start', {'boss': bossId, 'tier': tier});
      case BountyCleared(:final bossId, :final tier, :final reward):
        analytics.log('bounty_clear', {
          'boss': bossId,
          'tier': tier,
          'reward_type': reward.type,
          'reward_amount': reward.amount,
        });
      case BountyFailed(:final bossId, :final tier, :final reason, :final damageRatio):
        analytics.log('bounty_fail', {
          'boss': bossId,
          'tier': tier,
          'reason': reason,
          'damage_pct': (damageRatio * 100).round(),
        });
      case BountySwept(:final bossId, :final tier, :final count):
        analytics.log('bounty_sweep', {'boss': bossId, 'tier': tier, 'count': count});
      default:
        break;
    }
  }
}

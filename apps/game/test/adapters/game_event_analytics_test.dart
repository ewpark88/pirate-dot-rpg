import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/analytics/game_event_analytics.dart';

class _Recorder implements AnalyticsPort {
  final logs = <(String, Map<String, Object>)>[];

  @override
  void log(String event, [Map<String, Object> params = const {}]) => logs.add((event, params));

  @override
  void setLastSeen({required String screen, required int stage}) {}
}

void main() {
  test('현상금 이벤트 4종 → bounty_start/clear/fail/sweep, 다른 이벤트는 무시', () {
    final r = _Recorder();
    const reward = BountyReward(type: 'gems', amount: 12);
    logGameEvents(r, const [
      BountyStarted(1, bossId: 'kraken', tier: 3, timeLimitTicks: 600),
      WaveCleared(2, wave: 1),
      BountyCleared(3, bossId: 'kraken', tier: 3, reward: reward),
      BountyFailed(4, bossId: 'kraken', tier: 4, damageRatio: 0.624, reason: 'timeout'),
      BountySwept(5, bossId: 'kraken', tier: 3, count: 2, reward: reward),
    ]);
    expect([for (final (name, _) in r.logs) name], ['bounty_start', 'bounty_clear', 'bounty_fail', 'bounty_sweep']);
    expect(
      [for (final (_, params) in r.logs) params],
      [
        {'boss': 'kraken', 'tier': 3},
        {'boss': 'kraken', 'tier': 3, 'reward_type': 'gems', 'reward_amount': 12},
        {'boss': 'kraken', 'tier': 4, 'reason': 'timeout', 'damage_pct': 62},
        {'boss': 'kraken', 'tier': 3, 'count': 2},
      ],
    );
  });

  test('도감 이벤트 → dex_seen / dex_first_kill (보스는 1·0)', () {
    final r = _Recorder();
    logGameEvents(r, const [
      DexSeen(1, id: 'crab', boss: false),
      DexFirstKill(2, id: 'kraken', boss: true, gems: 5),
    ]);
    expect([for (final (name, _) in r.logs) name], ['dex_seen', 'dex_first_kill']);
    expect(
      [for (final (_, params) in r.logs) params],
      [
        {'id': 'crab', 'boss': 0},
        {'id': 'kraken', 'boss': 1, 'gems': 5},
      ],
    );
  });
}

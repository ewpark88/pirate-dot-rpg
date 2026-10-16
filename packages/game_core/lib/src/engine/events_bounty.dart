part of 'events.dart';

// 현상금 사냥 이벤트 (docs/specs/platform-content-bounty.md 5절, 요청 platform-bounty-b0b2.md B0).

GameEvent _bountyEventFromJson(int t, Json j) {
  final boss = j['bossId'] as String?;
  final tier = j['tier'] as int?;
  BountyReward reward() => BountyReward.fromJson(j['reward'] as Json);
  return switch (j['type'] as String) {
    'bountyStarted' => BountyStarted(t, bossId: boss!, tier: tier!, timeLimitTicks: j['timeLimitTicks'] as int),
    'bountyCleared' => BountyCleared(t, bossId: boss!, tier: tier!, reward: reward()),
    'bountyFailed' => BountyFailed(
      t,
      bossId: boss!,
      tier: tier!,
      damageRatio: (j['damageRatio'] as num).toDouble(),
      reason: j['reason'] as String,
    ),
    'bountySwept' => BountySwept(t, bossId: boss!, tier: tier!, count: j['count'] as int, reward: reward()),
    _ => BountyTicketsRefilled(t, count: j['count'] as int),
  };
}

class BountyStarted extends GameEvent {
  const BountyStarted(super.tick, {required this.bossId, required this.tier, required this.timeLimitTicks});

  final String bossId;
  final int tier;
  final int timeLimitTicks;

  @override
  String get type => 'bountyStarted';

  @override
  Json _fields() => {'bossId': bossId, 'tier': tier, 'timeLimitTicks': timeLimitTicks};
}

class BountyCleared extends GameEvent {
  const BountyCleared(super.tick, {required this.bossId, required this.tier, required this.reward});

  final String bossId;
  final int tier;
  final BountyReward reward;

  @override
  String get type => 'bountyCleared';

  @override
  Json _fields() => {'bossId': bossId, 'tier': tier, 'reward': reward.toJson()};
}

/// 실패 = 티켓 반환. [reason]: timeout | retreat | interrupted(앱이 뒤로·꺼짐) | sunk(배 침몰).
class BountyFailed extends GameEvent {
  const BountyFailed(
    super.tick, {
    required this.bossId,
    required this.tier,
    required this.damageRatio,
    required this.reason,
  });

  final String bossId;
  final int tier;

  /// 입힌 피해 ÷ 보스 HP (0~1).
  final double damageRatio;
  final String reason;

  @override
  String get type => 'bountyFailed';

  @override
  Json _fields() => {'bossId': bossId, 'tier': tier, 'damageRatio': damageRatio, 'reason': reason};
}

/// 소탕 [count]장 — [reward]는 합계.
class BountySwept extends GameEvent {
  const BountySwept(super.tick, {required this.bossId, required this.tier, required this.count, required this.reward});

  final String bossId;
  final int tier;
  final int count;
  final BountyReward reward;

  @override
  String get type => 'bountySwept';

  @override
  Json _fields() => {'bossId': bossId, 'tier': tier, 'count': count, 'reward': reward.toJson()};
}

class BountyTicketsRefilled extends GameEvent {
  const BountyTicketsRefilled(super.tick, {required this.count});

  final int count;

  @override
  String get type => 'bountyTicketsRefilled';

  @override
  Json _fields() => {'count': count};
}

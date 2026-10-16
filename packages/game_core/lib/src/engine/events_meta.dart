part of 'events.dart';

// 전투 밖(성장·경제·메타) 이벤트.

GameEvent _metaEventFromJson(int t, Json j) {
  BigNum big(String k) => BigNum.parse(j[k] as String);
  return switch (j['type'] as String) {
    'stageAdvanced' => StageAdvanced(t, stage: j['stage'] as int),
    'bestStageUpdated' => BestStageUpdated(t, stage: j['stage'] as int),
    'shipTierUp' => ShipTierUp(t, tierId: j['tierId'] as String),
    'partUpgraded' => PartUpgraded(t, part: j['part'] as String, level: j['level'] as int),
    'partMilestone' => PartMilestone(t, part: j['part'] as String, level: j['level'] as int),
    'crewSummoned' => CrewSummoned(
      t,
      results: [
        for (final r in j['results'] as List) (crewId: (r as Json)['crewId'] as String, rarity: r['rarity'] as String),
      ],
    ),
    'crewPromoted' => CrewPromoted(t, crewId: j['crewId'] as String, rarity: j['rarity'] as String),
    'chestSpawned' => ChestSpawned(t, x: (j['x'] as num).toDouble(), y: (j['y'] as num).toDouble()),
    'chestOpened' => ChestOpened(t, gold: big('gold')),
    'offlineReward' => OfflineReward(t, gold: big('gold'), cards: j['cards'] as int, seconds: j['seconds'] as int),
    'rebirthDone' || 'rebirthUpgradeBought' || 'skinUnlocked' || 'contentUnlocked' => _rebirthEventFromJson(t, j),
    'bossFired' => BossFired(t, x: (j['x'] as num).toDouble(), y: (j['y'] as num).toDouble()),
    'shipLookChanged' => ShipLookChanged(t, part: j['part'] as String, stage: j['stage'] as int),
    'fleetRejected' => FleetRejected(
      t,
      slot: j['slot'] as int,
      crewId: j['crewId'] as String,
      reason: j['reason'] as String,
    ),
    'seaEventStarted' ||
    'seaEventEnded' ||
    'goldfishCaught' ||
    'bottleOpened' ||
    'bottlePicked' ||
    'feverStarted' ||
    'feverEnded' ||
    'challengeStarted' ||
    'challengeProgress' ||
    'challengeEnded' => _funEventFromJson(t, j),
    'bountyStarted' ||
    'bountyCleared' ||
    'bountyFailed' ||
    'bountySwept' ||
    'bountyTicketsRefilled' => _bountyEventFromJson(t, j),
    'enemyFired' ||
    'enemyEmerging' ||
    'attackMissed' ||
    'shieldUp' ||
    'shieldBroken' ||
    'bossPattern' ||
    'crewSortie' ||
    'bombletBurst' => _threatEventFromJson(t, j),
    'goldOverflow' => GoldOverflow(t, lost: big('lost')),
    'fastSailStarted' || 'breakthroughStrike' || 'fastSailEnded' => _fastEventFromJson(t, j),
    'saveRequested' => SaveRequested(t, reason: j['reason'] as String),
    final other => throw FormatException('알 수 없는 이벤트', other),
  };
}

class StageAdvanced extends GameEvent {
  const StageAdvanced(super.tick, {required this.stage});

  final int stage;

  @override
  String get type => 'stageAdvanced';

  @override
  Json _fields() => {'stage': stage};
}

/// 최고 스테이지 갱신 → 2차 랭킹 제출 트리거.
class BestStageUpdated extends GameEvent {
  const BestStageUpdated(super.tick, {required this.stage});

  final int stage;

  @override
  String get type => 'bestStageUpdated';

  @override
  Json _fields() => {'stage': stage};
}

class ShipTierUp extends GameEvent {
  const ShipTierUp(super.tick, {required this.tierId});

  final String tierId;

  @override
  String get type => 'shipTierUp';

  @override
  Json _fields() => {'tierId': tierId};
}

class PartUpgraded extends GameEvent {
  const PartUpgraded(super.tick, {required this.part, required this.level});

  final String part;
  final int level;

  @override
  String get type => 'partUpgraded';

  @override
  Json _fields() => {'part': part, 'level': level};
}

/// 25레벨 도약: 효과 ×2 + 외형 변화 + 빛기둥.
class PartMilestone extends GameEvent {
  const PartMilestone(super.tick, {required this.part, required this.level});

  final String part;
  final int level;

  @override
  String get type => 'partMilestone';

  @override
  Json _fields() => {'part': part, 'level': level};
}

class CrewSummoned extends GameEvent {
  const CrewSummoned(super.tick, {required this.results});

  final List<({String crewId, String rarity})> results;

  @override
  String get type => 'crewSummoned';

  @override
  Json _fields() => {
    'results': [
      for (final r in results) {'crewId': r.crewId, 'rarity': r.rarity},
    ],
  };
}

class CrewPromoted extends GameEvent {
  const CrewPromoted(super.tick, {required this.crewId, required this.rarity});

  final String crewId;
  final String rarity;

  @override
  String get type => 'crewPromoted';

  @override
  Json _fields() => {'crewId': crewId, 'rarity': rarity};
}

class ChestSpawned extends GameEvent {
  const ChestSpawned(super.tick, {required this.x, required this.y});

  final double x;
  final double y;

  @override
  String get type => 'chestSpawned';

  @override
  Json _fields() => {'x': x, 'y': y};
}

class ChestOpened extends GameEvent {
  const ChestOpened(super.tick, {required this.gold});

  final BigNum gold;

  @override
  String get type => 'chestOpened';

  @override
  Json _fields() => {'gold': gold.toJson()};
}

class OfflineReward extends GameEvent {
  const OfflineReward(super.tick, {required this.gold, required this.cards, required this.seconds});

  final BigNum gold;
  final int cards;
  final int seconds;

  @override
  String get type => 'offlineReward';

  @override
  Json _fields() => {'gold': gold.toJson(), 'cards': cards, 'seconds': seconds};
}

/// 강화·소환·보스 클리어 직후 저장을 요청한다. 앱의 저장 어댑터가 듣는다.
class SaveRequested extends GameEvent {
  const SaveRequested(super.tick, {required this.reason});

  final String reason;

  @override
  String get type => 'saveRequested';

  @override
  Json _fields() => {'reason': reason};
}

/// 편성 거절 (SetFleetSlot). [reason]: `family` = 같은 계열 상한(skills.maxSameFamilyInFleet) 초과. UI는 안내 문구를 띄운다.
class FleetRejected extends GameEvent {
  const FleetRejected(super.tick, {required this.slot, required this.crewId, required this.reason});

  final int slot;
  final String crewId;
  final String reason;

  @override
  String get type => 'fleetRejected';

  @override
  Json _fields() => {'slot': slot, 'crewId': crewId, 'reason': reason};
}

/// 강화로 부위 외형 단계가 올랐다 (ship_parts.json visualStages). 렌더는 배 그림을 바꾸고, UI는 축하 연출.
/// 한 번에 여러 단계를 넘으면 마지막 단계로 한 번만.
class ShipLookChanged extends GameEvent {
  const ShipLookChanged(super.tick, {required this.part, required this.stage});

  final String part;
  final int stage;

  @override
  String get type => 'shipLookChanged';

  @override
  Json _fields() => {'part': part, 'stage': stage};
}

/// 보스 원거리 공격 한 번 (정지 지점 waves.boss.standoff에서). 피해는 같은 틱의 ShipDamaged. 렌더는 보스에서 배로 발사체를 그린다.
class BossFired extends GameEvent {
  const BossFired(super.tick, {required this.x, required this.y});

  final double x;
  final double y;

  @override
  String get type => 'bossFired';

  @override
  Json _fields() => {'x': x, 'y': y};
}

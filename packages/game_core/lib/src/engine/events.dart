import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:meta/meta.dart';

part 'events_meta.dart';

/// 코어가 내보내는 일. 효과음·데미지 숫자·파티클은 렌더가 이벤트를 보고 만든다.
///
/// JSONL 한 줄 = 이벤트 하나 (`fixtures/events/*.jsonl`, `game_cli export-events`).
@immutable
sealed class GameEvent {
  const GameEvent(this.tick);

  factory GameEvent.fromJson(Json j) {
    final t = j['t'] as int;
    BigNum big(String k) => BigNum.parse(j[k] as String);
    double d(String k) => (j[k] as num).toDouble();
    return switch (j['type'] as String) {
      'attackFired' => AttackFired(
        t,
        crewId: j['crewId'] as String,
        family: j['family'] as String,
        targetIds: (j['targetIds'] as List).cast<int>(),
        x: d('x'),
        y: d('y'),
      ),
      'damage' => Damage(
        t,
        targetId: j['targetId'] as int,
        amount: big('amount'),
        crit: j['crit'] as bool,
        crewId: j['crewId'] as String?,
      ),
      'aoeSum' => AoeDamageSum(t, total: big('total'), x: d('x'), y: d('y')),
      'kill' => Kill(t, targetId: j['targetId'] as int, gold: big('gold'), x: d('x'), y: d('y')),
      'multiKill' => MultiKill(t, count: j['count'] as int),
      'skillCast' => SkillCast(t, crewId: j['crewId'] as String, skillId: j['skillId'] as String, x: d('x'), y: d('y')),
      'ultimateCast' => UltimateCast(t, crewId: j['crewId'] as String, ultimateId: j['ultimateId'] as String),
      'hitStop' => HitStop(t, ticks: j['ticks'] as int, reason: j['reason'] as String),
      'shipDamaged' => ShipDamaged(t, amount: big('amount'), hpRatio: d('hpRatio')),
      'waveCleared' => WaveCleared(t, wave: j['wave'] as int),
      'bossSpawned' => BossSpawned(t, kind: j['kind'] as String, timeLimitTicks: j['timeLimitTicks'] as int),
      'bossCleared' => BossCleared(t, stage: j['stage'] as int, gems: j['gems'] as int),
      'bossFailed' => BossFailed(t, stage: j['stage'] as int),
      _ => _metaEventFromJson(t, j),
    };
  }

  /// 발생 틱(50ms 단위).
  final int tick;

  String get type;

  Json toJson() => {'t': tick, 'type': type, ..._fields()};

  Json _fields();

  @override
  String toString() => toJson().toString();
}

/// 선원이 발사했다 (발사체·슬롯 번쩍임). [x],[y]는 조준점.
class AttackFired extends GameEvent {
  const AttackFired(
    super.tick, {
    required this.crewId,
    required this.family,
    required this.targetIds,
    required this.x,
    required this.y,
  });

  final String crewId;
  final String family;
  final List<int> targetIds;
  final double x;
  final double y;

  @override
  String get type => 'attackFired';

  @override
  Json _fields() => {'crewId': crewId, 'family': family, 'targetIds': targetIds, 'x': x, 'y': y};
}

class Damage extends GameEvent {
  const Damage(super.tick, {required this.targetId, required this.amount, this.crit = false, this.crewId});

  final int targetId;
  final BigNum amount;
  final bool crit;
  final String? crewId;

  @override
  String get type => 'damage';

  @override
  Json _fields() => {'targetId': targetId, 'amount': amount.toJson(), 'crit': crit, 'crewId': crewId};
}

/// 범위 공격 한 번의 합산 피해 (큰 숫자 1개).
class AoeDamageSum extends GameEvent {
  const AoeDamageSum(super.tick, {required this.total, required this.x, required this.y});

  final BigNum total;
  final double x;
  final double y;

  @override
  String get type => 'aoeSum';

  @override
  Json _fields() => {'total': total.toJson(), 'x': x, 'y': y};
}

class Kill extends GameEvent {
  const Kill(super.tick, {required this.targetId, required this.gold, required this.x, required this.y});

  final int targetId;
  final BigNum gold;
  final double x;
  final double y;

  @override
  String get type => 'kill';

  @override
  Json _fields() => {'targetId': targetId, 'gold': gold.toJson(), 'x': x, 'y': y};
}

/// 0.5초 안 동시 처치. 문구는 waves.json multiKill.tiers.
class MultiKill extends GameEvent {
  const MultiKill(super.tick, {required this.count});

  final int count;

  @override
  String get type => 'multiKill';

  @override
  Json _fields() => {'count': count};
}

class SkillCast extends GameEvent {
  const SkillCast(super.tick, {required this.crewId, required this.skillId, required this.x, required this.y});

  final String crewId;
  final String skillId;
  final double x;
  final double y;

  @override
  String get type => 'skillCast';

  @override
  Json _fields() => {'crewId': crewId, 'skillId': skillId, 'x': x, 'y': y};
}

class UltimateCast extends GameEvent {
  const UltimateCast(super.tick, {required this.crewId, required this.ultimateId});

  final String crewId;
  final String ultimateId;

  @override
  String get type => 'ultimateCast';

  @override
  Json _fields() => {'crewId': crewId, 'ultimateId': ultimateId};
}

/// 히트스톱: 시뮬과 화면이 [ticks]만큼 함께 멈춘다. [reason]은 juice.json hitStopMs 키.
class HitStop extends GameEvent {
  const HitStop(super.tick, {required this.ticks, required this.reason});

  final int ticks;
  final String reason;

  @override
  String get type => 'hitStop';

  @override
  Json _fields() => {'ticks': ticks, 'reason': reason};
}

class ShipDamaged extends GameEvent {
  const ShipDamaged(super.tick, {required this.amount, required this.hpRatio});

  final BigNum amount;
  final double hpRatio;

  @override
  String get type => 'shipDamaged';

  @override
  Json _fields() => {'amount': amount.toJson(), 'hpRatio': hpRatio};
}

class WaveCleared extends GameEvent {
  const WaveCleared(super.tick, {required this.wave});

  final int wave;

  @override
  String get type => 'waveCleared';

  @override
  Json _fields() => {'wave': wave};
}

class BossSpawned extends GameEvent {
  const BossSpawned(super.tick, {required this.kind, required this.timeLimitTicks});

  final String kind;
  final int timeLimitTicks;

  @override
  String get type => 'bossSpawned';

  @override
  Json _fields() => {'kind': kind, 'timeLimitTicks': timeLimitTicks};
}

class BossCleared extends GameEvent {
  const BossCleared(super.tick, {required this.stage, required this.gems});

  final int stage;
  final int gems;

  @override
  String get type => 'bossCleared';

  @override
  Json _fields() => {'stage': stage, 'gems': gems};
}

/// 제한 시간 초과 또는 배 침몰 → 파밍 모드.
class BossFailed extends GameEvent {
  const BossFailed(super.tick, {required this.stage});

  final int stage;

  @override
  String get type => 'bossFailed';

  @override
  Json _fields() => {'stage': stage};
}

import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:meta/meta.dart';

part 'events_bestiary.dart';
part 'events_bounty.dart';
part 'events_fast.dart';
part 'events_fun.dart';
part 'events_meta.dart';
part 'events_rebirth.dart';
part 'events_stage.dart';
part 'events_threat.dart';

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
        fromX: (j['fromX'] as num?)?.toDouble(),
        fromY: (j['fromY'] as num?)?.toDouble(),
        angle: (j['angle'] as num?)?.toDouble(),
        flightTicks: j['flightTicks'] as int?,
        kind: j['kind'] as String?,
        splashRadius: (j['splashRadius'] as num?)?.toDouble(),
        beamTicks: j['beamTicks'] as int?,
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
      'skillCast' => SkillCast(
        t,
        crewId: j['crewId'] as String,
        skillId: j['skillId'] as String,
        x: d('x'),
        y: d('y'),
        scope: j['scope'] as String? ?? 'normal',
      ),
      'zoneSpawned' => ZoneSpawned(
        t,
        crewId: j['crewId'] as String,
        x: d('x'),
        y: d('y'),
        radius: d('radius'),
        ticks: j['ticks'] as int,
      ),
      'ultimateCast' => UltimateCast(t, crewId: j['crewId'] as String, ultimateId: j['ultimateId'] as String),
      'hitStop' => HitStop(t, ticks: j['ticks'] as int, reason: j['reason'] as String),
      'shipDamaged' => ShipDamaged(
        t,
        amount: big('amount'),
        hpRatio: d('hpRatio'),
        fromX: (j['fromX'] as num?)?.toDouble(),
        fromY: (j['fromY'] as num?)?.toDouble(),
      ),
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
    this.fromX,
    this.fromY,
    this.angle,
    this.flightTicks,
    this.kind,
    this.splashRadius,
    this.beamTicks,
  });

  final String crewId;
  final String family;
  final List<int> targetIds;

  /// 조준점.
  final double x;
  final double y;

  /// 탑다운 T0 선택 필드: 쏜 위치(포구)와 발사 방향(라디안, atan2(dy, dx)). 없으면 렌더가 배 위치에서 계산.
  final double? fromX;
  final double? fromY;
  final double? angle;

  /// 선원 개성 v2 선택 필드: 탄이 조준점에 닿기까지 틱(없으면 즉시). 닿을 때 Damage 또는 AttackMissed.
  final int? flightTicks;

  /// 연출 종류(선택, crews.json aim `kind` — 예 'lightning' 낙뢰). 없으면 계열 기본.
  final String? kind;

  /// 맞은 자리 폭발 반경(선택 — 전설 상위·신화, 렌더가 큰 임팩트).
  final double? splashRadius;

  /// 레이저 빔 유지 틱(선택, 계열 v3) — 그동안 매 틱 Damage.
  final int? beamTicks;

  @override
  String get type => 'attackFired';

  @override
  Json _fields() => {
    'crewId': crewId,
    'family': family,
    'targetIds': targetIds,
    'x': x,
    'y': y,
    if (fromX != null) 'fromX': fromX,
    if (fromY != null) 'fromY': fromY,
    if (angle != null) 'angle': angle,
    if (flightTicks != null) 'flightTicks': flightTicks,
    if (kind != null) 'kind': kind,
    if (splashRadius != null) 'splashRadius': splashRadius,
    if (beamTicks != null) 'beamTicks': beamTicks,
  };
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

/// 스킬 시전. 여러 곳에 떨어지는 스킬(count > 1)은 중심마다 하나씩 같은 틱에 나온다.
class SkillCast extends GameEvent {
  const SkillCast(
    super.tick, {
    required this.crewId,
    required this.skillId,
    required this.x,
    required this.y,
    this.scope = 'normal',
  });

  final String crewId;
  final String skillId;
  final double x;
  final double y;

  /// `normal` | `screen` (전설 이상 선원의 화면 전체 스킬).
  final String scope;

  @override
  String get type => 'skillCast';

  @override
  Json _fields() => {'crewId': crewId, 'skillId': skillId, 'x': x, 'y': y, 'scope': scope};
}

/// 지속 피해 장판(수중)이 생겼다. [ticks] 동안 남는다.
class ZoneSpawned extends GameEvent {
  const ZoneSpawned(
    super.tick, {
    required this.crewId,
    required this.x,
    required this.y,
    required this.radius,
    required this.ticks,
  });

  final String crewId;
  final double x;
  final double y;
  final double radius;
  final int ticks;

  @override
  String get type => 'zoneSpawned';

  @override
  Json _fields() => {'crewId': crewId, 'x': x, 'y': y, 'radius': radius, 'ticks': ticks};
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

part of 'events.dart';

// 배 위협 이벤트 (docs/specs/platform-ship-threat.md — 원거리 적·가까이 등장) + 선원 탄 빗나감(개성 v2).

GameEvent _threatEventFromJson(int t, Json j) => switch (j['type'] as String) {
  'enemyFired' => EnemyFired(
    t,
    enemyId: j['enemyId'] as int,
    fromX: (j['fromX'] as num).toDouble(),
    fromY: (j['fromY'] as num).toDouble(),
    flightTicks: j['flightTicks'] as int,
    kind: j['kind'] as String,
  ),
  'shieldUp' => ShieldUp(
    t,
    crewId: j['crewId'] as String,
    hp: BigNum.parse(j['hp'] as String),
    ticks: j['ticks'] as int,
  ),
  'shieldBroken' => ShieldBroken(t, crewId: j['crewId'] as String, reason: j['reason'] as String),
  'bossPattern' => BossPatternShown(
    t,
    enemyId: j['enemyId'] as int,
    kind: j['kind'] as String,
    phase: j['phase'] as String,
    warnTicks: j['warnTicks'] as int,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    angle: (j['angle'] as num).toDouble(),
    count: j['count'] as int,
    radius: (j['radius'] as num).toDouble(),
  ),
  'attackMissed' => AttackMissed(
    t,
    crewId: j['crewId'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
  ),
  _ => EnemyEmerging(
    t,
    enemyId: j['enemyId'] as int,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    warnTicks: j['warnTicks'] as int,
  ),
};

/// 원거리 적이 배를 향해 쐈다(침·가시·물대포 — [kind]). [flightTicks] 뒤 배가 맞는다(ShipDamaged.fromX·fromY = 쏜 자리).
class EnemyFired extends GameEvent {
  const EnemyFired(
    super.tick, {
    required this.enemyId,
    required this.fromX,
    required this.fromY,
    required this.flightTicks,
    required this.kind,
  });

  final int enemyId;
  final double fromX;
  final double fromY;
  final int flightTicks;
  final String kind;

  @override
  String get type => 'enemyFired';

  @override
  Json _fields() => {'enemyId': enemyId, 'fromX': fromX, 'fromY': fromY, 'flightTicks': flightTicks, 'kind': kind};
}

/// 적이 배 가까이에서 솟아오른다 — [warnTicks] 동안 물보라 예고(맞지도 때리지도 않음), 그 뒤 보통 적.
class EnemyEmerging extends GameEvent {
  const EnemyEmerging(super.tick, {required this.enemyId, required this.x, required this.y, required this.warnTicks});

  final int enemyId;
  final double x;
  final double y;
  final int warnTicks;

  @override
  String get type => 'enemyEmerging';

  @override
  Json _fields() => {'enemyId': enemyId, 'x': x, 'y': y, 'warnTicks': warnTicks};
}

/// 선원 탄이 도착했는데 맞을 적이 없다(선원 개성 v2 — 렌더 'MISS'). [x]·[y] = 떨어진 자리.
class AttackMissed extends GameEvent {
  const AttackMissed(super.tick, {required this.crewId, required this.x, required this.y});

  final String crewId;
  final double x;
  final double y;

  @override
  String get type => 'attackMissed';

  @override
  Json _fields() => {'crewId': crewId, 'x': x, 'y': y};
}

/// 보호막 선원(개성 v2 7.1)이 배에 흡수막 [hp]를 [ticks] 동안 세웠다.
class ShieldUp extends GameEvent {
  const ShieldUp(super.tick, {required this.crewId, required this.hp, required this.ticks});

  final String crewId;
  final BigNum hp;
  final int ticks;

  @override
  String get type => 'shieldUp';

  @override
  Json _fields() => {'crewId': crewId, 'hp': hp.toJson(), 'ticks': ticks};
}

/// 흡수막이 사라졌다 — [reason]: depleted(다 깎임) | expired(시간 끝).
class ShieldBroken extends GameEvent {
  const ShieldBroken(super.tick, {required this.crewId, required this.reason});

  final String crewId;
  final String reason;

  @override
  String get type => 'shieldBroken';

  @override
  Json _fields() => {'crewId': crewId, 'reason': reason};
}

/// 보스 행동 v2 패턴 (docs/specs/platform-boss-patterns.md). [kind]: volley | charge | summon | blast,
/// [phase]: warn(예고 [warnTicks] 동안 — 부채꼴 예고선·돌진 빨간 선·소환 물보라·배 둘레 원 [radius]) | act(동작) | cancel(예고 중 기절).
/// [angle] = 보스 → 배 방향(라디안), [count] = 탄막 발 수·소환 수.
class BossPatternShown extends GameEvent {
  const BossPatternShown(
    super.tick, {
    required this.enemyId,
    required this.kind,
    required this.phase,
    required this.warnTicks,
    required this.x,
    required this.y,
    required this.angle,
    required this.count,
    required this.radius,
  });

  final int enemyId;
  final String kind;
  final String phase;
  final int warnTicks;
  final double x;
  final double y;
  final double angle;
  final int count;
  final double radius;

  @override
  String get type => 'bossPattern';

  @override
  Json _fields() => {
    'enemyId': enemyId,
    'kind': kind,
    'phase': phase,
    'warnTicks': warnTicks,
    'x': x,
    'y': y,
    'angle': angle,
    'count': count,
    'radius': radius,
  };
}

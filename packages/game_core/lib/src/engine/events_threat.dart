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
  'enemyWindup' => EnemyWindup(
    t,
    enemyId: j['enemyId'] as int,
    atTicks: j['atTicks'] as int,
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
  'crewSortie' => CrewSortie(
    t,
    crewId: j['crewId'] as String,
    phase: j['phase'] as String,
    fromX: (j['fromX'] as num).toDouble(),
    fromY: (j['fromY'] as num).toDouble(),
    toX: (j['toX'] as num).toDouble(),
    toY: (j['toY'] as num).toDouble(),
    ticks: j['ticks'] as int,
  ),
  'bombletBurst' => BombletBurst(
    t,
    crewId: j['crewId'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    radius: (j['radius'] as num).toDouble(),
  ),
  'attackMissed' => AttackMissed(
    t,
    crewId: j['crewId'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    reason: j['reason'] as String?,
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

/// 원거리 적·보스가 [atTicks]틱 뒤 쏜다(쏘기 직전 예고 — 렌더가 쏘는 부위를 밝힌다, S1 2026-10-18).
/// [kind]: 'ranged'(잡몹 원거리) · 'boss'(보스 기본 포탄) · 'volley'(보스 일제 사격 패턴). 표 waves.top.windupSec(0이면 없음).
/// 예고만 — 발사 시점·피해는 그대로(sim 불변). 첫 발처럼 예고 시간보다 빨리 쏘게 되면 예고 없이 쏜다.
/// 보스 기본 포탄은 정지 지점 이동·패턴 쉼으로 늦게 쏠 수 있다(보통 atTicks 안, 일찍 쏘지는 않음).
class EnemyWindup extends GameEvent {
  const EnemyWindup(super.tick, {required this.enemyId, required this.atTicks, required this.kind});

  final int enemyId;
  final int atTicks;
  final String kind;

  @override
  String get type => 'enemyWindup';

  @override
  Json _fields() => {'enemyId': enemyId, 'atTicks': atTicks, 'kind': kind};
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
  const AttackMissed(super.tick, {required this.crewId, required this.x, required this.y, this.reason});

  final String crewId;
  final double x;
  final double y;

  /// 왜 빗나갔나 — null = 탄이 빈자리에, 'evade' = 보스 특성 회피(S3 잔상 연출). 선택 키.
  final String? reason;

  @override
  String get type => 'attackMissed';

  @override
  Json _fields() => {'crewId': crewId, 'x': x, 'y': y, 'reason': ?reason};
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

/// 선원 본인 출격 (계열 행동 v3 — 강습·공중). [phase]: out(배 → 적) · strike(꽂혀 휘두름, 피해는 이 시작에) · back(적 → 배).
/// ([fromX],[fromY]) → ([toX],[toY])를 [ticks] 동안. 렌더가 선원 초상을 이 길로 날린다.
class CrewSortie extends GameEvent {
  const CrewSortie(
    super.tick, {
    required this.crewId,
    required this.phase,
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    required this.ticks,
  });

  final String crewId;
  final String phase;
  final double fromX;
  final double fromY;
  final double toX;
  final double toY;
  final int ticks;

  @override
  String get type => 'crewSortie';

  @override
  Json _fields() => {
    'crewId': crewId,
    'phase': phase,
    'fromX': fromX,
    'fromY': fromY,
    'toX': toX,
    'toY': toY,
    'ticks': ticks,
  };
}

/// 집속탄 자탄 하나가 터졌다(계열 v3 — 0.1초 간격 연쇄). 맞은 적이 있으면 같은 틱 Damage.
class BombletBurst extends GameEvent {
  const BombletBurst(super.tick, {required this.crewId, required this.x, required this.y, required this.radius});

  final String crewId;
  final double x;
  final double y;
  final double radius;

  @override
  String get type => 'bombletBurst';

  @override
  Json _fields() => {'crewId': crewId, 'x': x, 'y': y, 'radius': radius};
}

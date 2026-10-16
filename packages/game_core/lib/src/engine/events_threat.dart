part of 'events.dart';

// 배 위협 이벤트 (docs/specs/platform-ship-threat.md — 원거리 적·가까이 등장).

GameEvent _threatEventFromJson(int t, Json j) => switch (j['type'] as String) {
  'enemyFired' => EnemyFired(
    t,
    enemyId: j['enemyId'] as int,
    fromX: (j['fromX'] as num).toDouble(),
    fromY: (j['fromY'] as num).toDouble(),
    flightTicks: j['flightTicks'] as int,
    kind: j['kind'] as String,
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

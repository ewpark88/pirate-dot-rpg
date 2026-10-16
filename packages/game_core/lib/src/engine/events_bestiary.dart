part of 'events.dart';

// 도감 v2 이벤트 (docs/specs/platform-bestiary-v2.md — 먹물·삼키기·분열·자폭).

GameEvent _bestiaryEventFromJson(int t, Json j) => switch (j['type'] as String) {
  'inkCloud' => InkCloud(
    t,
    enemyId: j['enemyId'] as int,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    radius: (j['radius'] as num).toDouble(),
    ticks: j['ticks'] as int,
  ),
  'bossSwallowed' => BossSwallowed(
    t,
    enemyId: j['enemyId'] as int,
    eaten: (j['eaten'] as List).cast<int>(),
    healed: BigNum.parse(j['healed'] as String),
  ),
  'bossSplit' => BossSplit(
    t,
    parentId: j['parentId'] as int,
    childId: j['childId'] as int,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
  ),
  _ => BomberBlast(
    t,
    enemyId: j['enemyId'] as int,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    radius: (j['radius'] as num).toDouble(),
    onShip: j['onShip'] as bool,
  ),
};

/// 먹물 구름: ([x],[y]) 반경 [radius] 안 적은 [ticks] 동안 조준되지 않는다(선원이 못 본다).
class InkCloud extends GameEvent {
  const InkCloud(
    super.tick, {
    required this.enemyId,
    required this.x,
    required this.y,
    required this.radius,
    required this.ticks,
  });

  final int enemyId;
  final double x;
  final double y;
  final double radius;
  final int ticks;

  @override
  String get type => 'inkCloud';

  @override
  Json _fields() => {'enemyId': enemyId, 'x': x, 'y': y, 'radius': radius, 'ticks': ticks};
}

/// 보스가 잡몹을 삼켰다([eaten] id들, 보상 없음) — HP [healed] 회복.
class BossSwallowed extends GameEvent {
  const BossSwallowed(super.tick, {required this.enemyId, required this.eaten, required this.healed});

  final int enemyId;
  final List<int> eaten;
  final BigNum healed;

  @override
  String get type => 'bossSwallowed';

  @override
  Json _fields() => {'enemyId': enemyId, 'eaten': eaten, 'healed': healed.toJson()};
}

/// 보스가 둘로 갈라졌다 — 새 몸 [childId]가 ([x],[y])에. 둘 다 잡아야 격파.
class BossSplit extends GameEvent {
  const BossSplit(super.tick, {required this.parentId, required this.childId, required this.x, required this.y});

  final int parentId;
  final int childId;
  final double x;
  final double y;

  @override
  String get type => 'bossSplit';

  @override
  Json _fields() => {'parentId': parentId, 'childId': childId, 'x': x, 'y': y};
}

/// 자폭 적이 터졌다: [onShip]이면 배에 박아 터짐(ShipDamaged가 같이), 아니면 잡혀서 주변 적에게 폭발.
class BomberBlast extends GameEvent {
  const BomberBlast(
    super.tick, {
    required this.enemyId,
    required this.x,
    required this.y,
    required this.radius,
    required this.onShip,
  });

  final int enemyId;
  final double x;
  final double y;
  final double radius;
  final bool onShip;

  @override
  String get type => 'bomberBlast';

  @override
  Json _fields() => {'enemyId': enemyId, 'x': x, 'y': y, 'radius': radius, 'onShip': onShip};
}

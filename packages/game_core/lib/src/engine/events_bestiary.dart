part of 'events.dart';

// 도감 v2 이벤트 (docs/specs/platform-bestiary-v2.md — 먹물·삼키기·분열·자폭).

GameEvent _bestiaryEventFromJson(int t, Json j) => switch (j['type'] as String) {
  'bossAttackMissed' => BossAttackMissed(
    t,
    enemyId: j['enemyId'] as int,
    kind: j['kind'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
  ),
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
  'bossTraitFired' => BossTraitFired(
    t,
    enemyId: j['enemyId'] as int,
    trait: j['trait'] as String,
    ticks: j['ticks'] as int? ?? 0,
  ),
  'bossBarBroken' => BossBarBroken(
    t,
    enemyId: j['enemyId'] as int,
    bar: j['bar'] as int,
    barsLeft: j['barsLeft'] as int,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
  ),
  'hordeIncoming' => HordeIncoming(t, stage: j['stage'] as int, count: j['count'] as int),
  'bossBroken' => BossBroken(
    t,
    enemyId: j['enemyId'] as int,
    ticks: j['ticks'] as int,
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

/// 보스 체력 층이 깨졌다(boss-feel, 사용자 '보스전 밋밋' 2026-10-17): [bar]번째 층(위에서부터 센 번호, 남은 층 수 기준)이 깨져
/// [barsLeft]층 남음. 보스는 waves.boss.bars.staggerSec 동안 비틀(기절 + 받는 피해 × staggerDamageMul). 마지막 층(처치)은 없음.
class BossBarBroken extends GameEvent {
  const BossBarBroken(
    super.tick, {
    required this.enemyId,
    required this.bar,
    required this.barsLeft,
    required this.x,
    required this.y,
  });

  final int enemyId;
  final int bar;
  final int barsLeft;
  final double x;
  final double y;

  @override
  String get type => 'bossBarBroken';

  @override
  Json _fields() => {'enemyId': enemyId, 'bar': bar, 'barsLeft': barsLeft, 'x': x, 'y': y};
}

/// 대군 습격(사용자 2026-10-17 '스테이지를 넘어갈 때마다 많이 몰려들게'): 스테이지 첫 파로 [count]마리가 사방에서 한꺼번에
/// 온다(waves.top.horde). 렌더·UI는 배너('대군 습격!')·화면 흔들림 등으로 알린다.
class HordeIncoming extends GameEvent {
  const HordeIncoming(super.tick, {required this.stage, required this.count});

  final int stage;
  final int count;

  @override
  String get type => 'hordeIncoming';

  @override
  Json _fields() => {'stage': stage, 'count': count};
}

/// 보스 브레이크(사용자 결정 2026-10-17): 게이지가 가득 차 보스가 [ticks] 동안 쓰러졌다 — 그동안 받는 피해 × damageMul.
class BossBroken extends GameEvent {
  const BossBroken(super.tick, {required this.enemyId, required this.ticks, required this.x, required this.y});

  final int enemyId;
  final int ticks;
  final double x;
  final double y;

  @override
  String get type => 'bossBroken';

  @override
  Json _fields() => {'enemyId': enemyId, 'ticks': ticks, 'x': x, 'y': y};
}

/// 보스 특성이 움직였다(docs/specs/economy-boss-traits.md): [trait] 'reflect'(반사막 — 예고 뒤 [ticks] 동안) · 'enrage'(분노) ·
/// 'escort'(호위 소환) · 'dash'(가속 — [ticks] 동안 자리 옮김). 회피는 AttackMissed(reason 'evade').
class BossTraitFired extends GameEvent {
  const BossTraitFired(super.tick, {required this.enemyId, required this.trait, this.ticks = 0});

  final int enemyId;
  final String trait;
  final int ticks;

  @override
  String get type => 'bossTraitFired';

  @override
  Json _fields() => {'enemyId': enemyId, 'trait': trait, if (ticks != 0) 'ticks': ticks};
}

// events.dart 300줄 — 궁극기 사용은 보스전 손맛(필살기 manual)과 함께 여기로(boss-feel).
class UltimateCast extends GameEvent {
  const UltimateCast(super.tick, {required this.crewId, required this.ultimateId, this.manual = false});

  final String crewId;
  final String ultimateId;

  /// 선장 필살기 버튼으로 쓴 것(TriggerUltimate, 자동 필살기 끔). 피버 첫 일격·자동 사용은 false. 선택 키.
  final bool manual;

  @override
  String get type => 'ultimateCast';

  @override
  Json _fields() => {'crewId': crewId, 'ultimateId': ultimateId, if (manual) 'manual': true};
}

/// 보스 공격이 빗나갔다(보스 회피 — waves.top.bossDodge): [kind] volley·blast·charge, [x]·[y] = 조준 자리(돌진은 멈춘 자리).
/// 렌더는 빗나감 물보라·MISS.
class BossAttackMissed extends GameEvent {
  const BossAttackMissed(super.tick, {required this.enemyId, required this.kind, required this.x, required this.y});

  final int enemyId;
  final String kind;
  final double x;
  final double y;

  @override
  String get type => 'bossAttackMissed';

  @override
  Json _fields() => {'enemyId': enemyId, 'kind': kind, 'x': x, 'y': y};
}

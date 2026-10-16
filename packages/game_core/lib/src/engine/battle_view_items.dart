part of 'battle_view.dart';

// 전장 스냅샷의 조각: 적·슬롯·상자 (battle_view.dart가 300줄을 넘어 나눔).

@immutable
class EnemyView {
  const EnemyView({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.hpRatio,
    this.layer = 'surface',
    this.boss = false,
    this.stunned = false,
    this.shielded = false,
    this.tier = 0,
    this.slowed = false,
    this.burning = false,
    this.vulnerable = false,
    this.heading = sideHeading,
    this.eventKind,
  });

  factory EnemyView.fromJson(Json j) => EnemyView(
    id: j['id'] as int,
    kind: j['kind'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    hpRatio: (j['hpRatio'] as num).toDouble(),
    layer: j['layer'] as String? ?? 'surface',
    boss: j['boss'] as bool? ?? false,
    stunned: j['stunned'] as bool? ?? false,
    shielded: j['shielded'] as bool? ?? false,
    tier: j['tier'] as int? ?? 0,
    slowed: j['slowed'] as bool? ?? false,
    burning: j['burning'] as bool? ?? false,
    vulnerable: j['vulnerable'] as bool? ?? false,
    heading: (j['heading'] as num?)?.toDouble() ?? sideHeading,
    eventKind: j['eventKind'] as String?,
  );

  /// 옆모습의 적 진행 방향(왼쪽) — 라디안, 0 = 오른쪽, 반시계(수학 좌표, y는 화면 아래로).
  static const double sideHeading = math.pi;

  /// 전투 동안 유일한 id. 이벤트가 이 id로 대상을 가리킨다.
  final int id;

  /// regions.json의 enemies[].id 또는 보스 id.
  final String kind;
  final double x;
  final double y;
  final double hpRatio;

  /// `surface` | `underwater` | `air`.
  final String layer;
  final bool boss;

  /// 기절 중 (머리 위 별).
  final bool stunned;

  /// 보호막 중 (보스 패턴: 피해 0).
  final bool shielded;

  /// 무한 항해 등급 테두리: 0 없음, 1 희귀, 2 영웅, 3 전설.
  final int tier;

  /// 상태 표시 (전설 능력): 감속 중, 화상 중, 받는 피해 증가 중.
  final bool slowed;
  final bool burning;
  final bool vulnerable;

  /// 이동 방향(라디안, atan2(dy, dx)). 탑다운 렌더가 도트를 돌린다. 옆모습은 [sideHeading].
  final double heading;

  /// 돌발 이벤트 적이면 종류(goldfish | merchant | ambush) — 렌더가 그림을 고른다. 보통 적은 null.
  final String? eventKind;

  Json toJson() => {
    'id': id,
    'kind': kind,
    'x': x,
    'y': y,
    'hpRatio': hpRatio,
    'layer': layer,
    'boss': boss,
    'stunned': stunned,
    'shielded': shielded,
    'tier': tier,
    'slowed': slowed,
    'burning': burning,
    'vulnerable': vulnerable,
    if (heading != sideHeading) 'heading': heading,
    if (eventKind != null) 'eventKind': eventKind,
  };
}

/// 화면 아래 무기 슬롯 하나 (출전 선원).
@immutable
class FleetSlot {
  const FleetSlot({required this.crewId, this.cooldown = 0, this.skillCooldown = 0, this.rarity = 0});

  factory FleetSlot.fromJson(Json j) => FleetSlot(
    crewId: j['crewId'] as String,
    cooldown: (j['cooldown'] as num).toDouble(),
    skillCooldown: (j['skillCooldown'] as num).toDouble(),
    rarity: (j['rarity'] as int?) ?? 0,
  );

  final String crewId;

  /// 현재 등급 순번 (`rarities.json` 순서, 0 = 일반). 승급하면 바로 바뀐다 — 선원 바 테두리 색 (계약 I, 렌더 요청).
  final int rarity;

  /// 남은 공격 쿨타임 비율 0(준비)~1(방금 발사). 슬롯의 어두운 덮개.
  final double cooldown;

  /// 남은 스킬 쿨타임 비율.
  final double skillCooldown;

  Json toJson() => {'crewId': crewId, 'cooldown': cooldown, 'skillCooldown': skillCooldown, 'rarity': rarity};
}

/// 바다에 떠 있는 보물상자 (설계서 4.6). 탭하면 TapChest. 경제 레인이 띄우고 치운다.
@immutable
class ChestView {
  const ChestView({required this.x, required this.y, required this.ticksLeft});

  factory ChestView.fromJson(Json j) =>
      ChestView(x: (j['x'] as num).toDouble(), y: (j['y'] as num).toDouble(), ticksLeft: j['ticksLeft'] as int);

  final double x;
  final double y;

  /// 가라앉을 때까지 남은 틱.
  final int ticksLeft;

  Json toJson() => {'x': x, 'y': y, 'ticksLeft': ticksLeft};
}

/// 진행 중인 돌발 이벤트 (전장 위 띠·유리병 말풍선). 저장하지 않는다.
@immutable
class SeaEventView {
  const SeaEventView({required this.id, required this.ticksLeft, this.choices = const []});

  factory SeaEventView.fromJson(Json j) => SeaEventView(
    id: j['id'] as String,
    ticksLeft: j['ticksLeft'] as int,
    choices: (j['choices'] as List?)?.cast<String>() ?? const [],
  );

  /// goldfish | merchant | ambush | bottle | storm.
  final String id;
  final int ticksLeft;

  /// 유리병 쪽지 종류(bottle일 때만, PickBottle(index)).
  final List<String> choices;

  Json toJson() => {'id': id, 'ticksLeft': ticksLeft, if (choices.isNotEmpty) 'choices': choices};
}

/// 진행 중인 즉석 도전 (전장 위 띠: '30초 안에 [value]/[target]').
@immutable
class ChallengeView {
  const ChallengeView({required this.id, required this.target, required this.value, required this.ticksLeft});

  factory ChallengeView.fromJson(Json j) => ChallengeView(
    id: j['id'] as String,
    target: j['target'] as int,
    value: j['value'] as int,
    ticksLeft: j['ticksLeft'] as int,
  );

  final String id;
  final int target;
  final int value;
  final int ticksLeft;

  Json toJson() => {'id': id, 'target': target, 'value': value, 'ticksLeft': ticksLeft};
}

/// 현상금 전투 표시 (현상금 B0): 보스·단계·남은 틱.
@immutable
class BountyView {
  const BountyView({required this.bossId, required this.tier, required this.ticksLeft});

  factory BountyView.fromJson(Json j) =>
      BountyView(bossId: j['bossId'] as String, tier: j['tier'] as int, ticksLeft: j['ticksLeft'] as int);

  final String bossId;
  final int tier;
  final int ticksLeft;

  Json toJson() => {'bossId': bossId, 'tier': tier, 'ticksLeft': ticksLeft};
}

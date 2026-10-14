import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:meta/meta.dart';

/// 전장 좌표계: 논리 화면 320×180 중 전장 0~148 (docs/GAME_DESIGN.md 10장).
/// 렌더는 이 좌표를 두 틱 사이로 보간해 그린다. 세이브에는 들어가지 않는다.
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
  );

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
  };
}

/// 화면 아래 무기 슬롯 하나 (출전 선원).
@immutable
class FleetSlot {
  const FleetSlot({required this.crewId, this.cooldown = 0, this.skillCooldown = 0});

  factory FleetSlot.fromJson(Json j) => FleetSlot(
    crewId: j['crewId'] as String,
    cooldown: (j['cooldown'] as num).toDouble(),
    skillCooldown: (j['skillCooldown'] as num).toDouble(),
  );

  final String crewId;

  /// 남은 공격 쿨타임 비율 0(준비)~1(방금 발사). 슬롯의 어두운 덮개.
  final double cooldown;

  /// 남은 스킬 쿨타임 비율.
  final double skillCooldown;

  Json toJson() => {'crewId': crewId, 'cooldown': cooldown, 'skillCooldown': skillCooldown};
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

@immutable
class BattleView {
  const BattleView({
    required this.shipHp,
    required this.shipHpMax,
    this.tick = 0,
    this.bossActive = false,
    this.bossTicksLeft = 0,
    this.enemies = const [],
    this.fleet = const [],
    this.captainId,
    this.hitStopTicks = 0,
    this.speed = 1,
    this.stage = 1,
    this.chest,
    this.wave = 0,
    this.rage = 0,
    this.gold = BigNum.zero,
  });

  factory BattleView.fromJson(Json j) => BattleView(
    tick: j['tick'] as int,
    shipHp: BigNum.parse(j['shipHp'] as String),
    shipHpMax: BigNum.parse(j['shipHpMax'] as String),
    bossActive: j['bossActive'] as bool,
    bossTicksLeft: j['bossTicksLeft'] as int,
    enemies: [for (final e in j['enemies'] as List) EnemyView.fromJson(e as Json)],
    fleet: [for (final f in j['fleet'] as List) FleetSlot.fromJson(f as Json)],
    captainId: j['captainId'] as String?,
    hitStopTicks: j['hitStopTicks'] as int,
    speed: j['speed'] as int? ?? 1,
    stage: j['stage'] as int? ?? 1,
    chest: j['chest'] == null ? null : ChestView.fromJson(j['chest'] as Json),
    wave: j['wave'] as int? ?? 0,
    rage: (j['rage'] as num?)?.toDouble() ?? 0,
    gold: j['gold'] == null ? BigNum.zero : BigNum.parse(j['gold'] as String),
  );

  static const empty = BattleView(shipHp: BigNum.one, shipHpMax: BigNum.one);

  /// 엔진 시작 후 지난 틱 수(50ms 단위).
  final int tick;
  final BigNum shipHp;
  final BigNum shipHpMax;
  final bool bossActive;
  final int bossTicksLeft;
  final List<EnemyView> enemies;
  final List<FleetSlot> fleet;

  /// 가장 등급 높은 출전 선원. 궁극기 계열을 정한다.
  final String? captainId;

  /// 남은 히트스톱 틱. 0보다 크면 시뮬과 화면이 함께 멈춘다.
  final int hitStopTicks;

  /// 배속 (운영자·순풍). 1, 2, 4.
  final int speed;

  /// 지금 스테이지 (기록 재생에서도 해역 배경을 알 수 있게).
  final int stage;

  /// 떠 있는 보물상자. 없으면 null.
  final ChestView? chest;

  /// 캔버스 HUD용 (기록 재생에서도 그리게): 이번 스테이지에서 잡은 파 수, 함성 게이지 0~1, 지갑 골드.
  final int wave;
  final double rage;
  final BigNum gold;

  /// [chest]를 없애려면 [clearChest].
  BattleView copyWith({
    int? tick,
    BigNum? shipHp,
    BigNum? shipHpMax,
    bool? bossActive,
    int? bossTicksLeft,
    List<EnemyView>? enemies,
    List<FleetSlot>? fleet,
    String? captainId,
    int? hitStopTicks,
    int? speed,
    int? stage,
    ChestView? chest,
    bool clearChest = false,
    int? wave,
    double? rage,
    BigNum? gold,
  }) => BattleView(
    tick: tick ?? this.tick,
    shipHp: shipHp ?? this.shipHp,
    shipHpMax: shipHpMax ?? this.shipHpMax,
    bossActive: bossActive ?? this.bossActive,
    bossTicksLeft: bossTicksLeft ?? this.bossTicksLeft,
    enemies: enemies ?? this.enemies,
    fleet: fleet ?? this.fleet,
    captainId: captainId ?? this.captainId,
    hitStopTicks: hitStopTicks ?? this.hitStopTicks,
    speed: speed ?? this.speed,
    stage: stage ?? this.stage,
    chest: clearChest ? null : chest ?? this.chest,
    wave: wave ?? this.wave,
    rage: rage ?? this.rage,
    gold: gold ?? this.gold,
  );

  Json toJson() => {
    'tick': tick,
    'shipHp': shipHp.toJson(),
    'shipHpMax': shipHpMax.toJson(),
    'bossActive': bossActive,
    'bossTicksLeft': bossTicksLeft,
    'enemies': [for (final e in enemies) e.toJson()],
    'fleet': [for (final f in fleet) f.toJson()],
    'captainId': captainId,
    'hitStopTicks': hitStopTicks,
    'speed': speed,
    'stage': stage,
    'chest': chest?.toJson(),
    'wave': wave,
    'rage': rage,
    'gold': gold.toJson(),
  };
}

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
  };
}

import 'dart:math' as math;

import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:meta/meta.dart';

part 'battle_view_items.dart';

/// 전장 좌표계: 논리 화면 320×180 중 전장 0~148 (docs/GAME_DESIGN.md 10장).
/// 렌더는 이 좌표를 두 틱 사이로 보간해 그린다. 세이브에는 들어가지 않는다.
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
    this.shipLook = const {},
    this.mode = 'side',
    this.shipX,
    this.shipY,
    this.shipHeading = 0,
    this.shipTierLook,
    this.shipSkin,
    this.treasureSea,
    this.shipShield = 0,
    this.fever = 0,
    this.feverTicksLeft = 0,
    this.seaEvent,
    this.challenge,
    this.bounty,
    this.fastSail,
    this.crewDamage = const {},
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
    shipLook: {for (final e in (j['shipLook'] as Json? ?? const {}).entries) e.key: e.value as int},
    mode: j['mode'] as String? ?? 'side',
    shipX: (j['shipX'] as num?)?.toDouble(),
    shipY: (j['shipY'] as num?)?.toDouble(),
    shipHeading: (j['shipHeading'] as num?)?.toDouble() ?? 0,
    shipTierLook: j['shipTierLook'] as String?,
    shipSkin: j['shipSkin'] as String?,
    treasureSea: j['treasureSea'] as int?,
    shipShield: (j['shipShield'] as num?)?.toDouble() ?? 0,
    fever: (j['fever'] as num?)?.toDouble() ?? 0,
    feverTicksLeft: j['feverTicksLeft'] as int? ?? 0,
    seaEvent: j['seaEvent'] == null ? null : SeaEventView.fromJson(j['seaEvent'] as Json),
    challenge: j['challenge'] == null ? null : ChallengeView.fromJson(j['challenge'] as Json),
    bounty: j['bounty'] == null ? null : BountyView.fromJson(j['bounty'] as Json),
    fastSail: j['fastSail'] == null ? null : FastSailView.fromJson(j['fastSail'] as Json),
    crewDamage: {
      for (final e in (j['crewDamage'] as Json? ?? const {}).entries) e.key: BigNum.parse(e.value as String),
    },
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

  /// 부위별 외형 단계 (ship_parts.json visualStages, 경제 partLook). 렌더가 배 그림을 고른다. 없으면 빈 맵.
  final Map<String, int> shipLook;

  /// 전장 방식 `side` | `top` (Settings.battleView, 탑다운 전환 T0). 옛 기록은 side.
  final String mode;

  /// 배 중심(필드 좌표). null이면 방식의 테이블 값(side: waves.field.shipX·shipY, top: waves.top.shipX·shipY).
  final double? shipX;
  final double? shipY;

  /// 배가 향하는 방향(라디안, 0 = 화면 위쪽, 시계 방향). 탑다운 렌더가 배를 돌린다.
  final double shipHeading;

  /// 배 등급 그림 id = max(지금 등급, 명예 등급) (환생 v2 — 그림만, 능력치는 지금 등급). 없으면 렌더가 스테이지로 고른다.
  final String? shipTierLook;

  /// 장착한 환생 스킨 id (meta.rebirth.skins, null = 기본 배).
  final String? shipSkin;

  /// 이번 회차 보물 바다 해역 번호 (null = 보통 바다) — 렌더가 금빛 물결을 덮는다.
  final int? treasureSea;

  /// 배 흡수막 남은 비율 0~1(선원 개성 v2 7.1 보호막). 0이면 JSON에 키가 없다.
  final double shipShield;

  /// 피버 게이지 0~1 (전장 위 얇은 막대). 피버 중이면 [feverTicksLeft] > 0.
  final double fever;
  final int feverTicksLeft;

  /// 진행 중인 돌발 이벤트·즉석 도전 (없으면 null).
  final SeaEventView? seaEvent;
  final ChallengeView? challenge;

  /// 현상금 전투 중이면 그 보스·단계·남은 틱 (현상금 B0). 없으면 JSON에 키가 없다.
  final BountyView? bounty;

  /// 빠른 항해 돌파 중이면 구간·연속 격파(선택 키).
  final FastSailView? fastSail;

  /// 이번 스테이지 선원별 실제 피해(남은 HP로 자름, 선원 몫만) — 선원 칸 피해 표시(#13). 비면 JSON에 키가 없다.
  final Map<String, BigNum> crewDamage;

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
    double? fever,
    int? feverTicksLeft,
    SeaEventView? seaEvent,
    bool clearSeaEvent = false,
    ChallengeView? challenge,
    bool clearChallenge = false,
    BountyView? bounty,
    bool clearBounty = false,
    Map<String, int>? shipLook,
    String? mode,
    double? shipX,
    double? shipY,
    double? shipHeading,
    double? shipShield,
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
    fever: fever ?? this.fever,
    feverTicksLeft: feverTicksLeft ?? this.feverTicksLeft,
    seaEvent: clearSeaEvent ? null : seaEvent ?? this.seaEvent,
    challenge: clearChallenge ? null : challenge ?? this.challenge,
    bounty: clearBounty ? null : bounty ?? this.bounty,
    shipLook: shipLook ?? this.shipLook,
    mode: mode ?? this.mode,
    shipX: shipX ?? this.shipX,
    shipY: shipY ?? this.shipY,
    shipHeading: shipHeading ?? this.shipHeading,
    shipTierLook: shipTierLook,
    shipSkin: shipSkin,
    treasureSea: treasureSea,
    shipShield: shipShield ?? this.shipShield,
    fastSail: fastSail,
    crewDamage: crewDamage,
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
    'shipLook': shipLook,
    // 탑다운 T0 선택 키: 기본값이면 쓰지 않는다(옛 기록·픽스처와 같은 본문).
    if (mode != 'side') 'mode': mode,
    if (shipX != null) 'shipX': shipX,
    if (shipY != null) 'shipY': shipY,
    if (shipHeading != 0) 'shipHeading': shipHeading,
    if (shipTierLook != null) 'shipTierLook': shipTierLook,
    if (shipSkin != null) 'shipSkin': shipSkin,
    if (treasureSea != null) 'treasureSea': treasureSea,
    if (shipShield > 0) 'shipShield': shipShield,
    if (fever != 0) 'fever': fever,
    if (feverTicksLeft != 0) 'feverTicksLeft': feverTicksLeft,
    if (seaEvent != null) 'seaEvent': seaEvent!.toJson(),
    if (challenge != null) 'challenge': challenge!.toJson(),
    if (bounty != null) 'bounty': bounty!.toJson(),
    if (fastSail != null) 'fastSail': fastSail!.toJson(),
    if (crewDamage.isNotEmpty) 'crewDamage': {for (final e in crewDamage.entries) e.key: e.value.toJson()},
  };

  /// 배 겉모습 세 값을 그대로 넣는다(null도 그대로 — copyWith로는 지울 수 없어서).
  BattleView withShipDress({String? tierLook, String? skin, int? treasureSea}) => BattleView(
    tick: tick,
    shipHp: shipHp,
    shipHpMax: shipHpMax,
    bossActive: bossActive,
    bossTicksLeft: bossTicksLeft,
    enemies: enemies,
    fleet: fleet,
    captainId: captainId,
    hitStopTicks: hitStopTicks,
    speed: speed,
    stage: stage,
    chest: chest,
    wave: wave,
    rage: rage,
    gold: gold,
    shipLook: shipLook,
    mode: mode,
    shipX: shipX,
    shipY: shipY,
    shipHeading: shipHeading,
    shipTierLook: tierLook,
    shipSkin: skin,
    treasureSea: treasureSea,
    shipShield: shipShield,
    fever: fever,
    feverTicksLeft: feverTicksLeft,
    seaEvent: seaEvent,
    challenge: challenge,
    bounty: bounty,
    fastSail: fastSail,
    crewDamage: crewDamage,
  );
}

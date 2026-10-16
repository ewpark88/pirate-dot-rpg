import 'package:game_core/src/battle/topdown/geometry.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_data/game_data.dart';

export 'package:game_core/src/battle/topdown/geometry.dart' show geometryFor, shapeField;

/// 전장의 적 하나. 시뮬 내부 값(실제 HP·접촉 타이머·기절)을 들고, 화면에는 [EnemyView]로 나간다.
class Foe {
  Foe({
    required this.id,
    required this.kind,
    required this.layer,
    required this.x,
    required this.y,
    required this.maxHp,
    required this.speed,
    required this.attack,
    required this.gold,
    this.boss = false,
    this.def,
    this.bossDef,
    this.ownerId,
    this.tier = 0,
    this.eventKind,
  }) : hp = maxHp;

  final int id;
  final String kind;
  final String layer;
  double x;
  double y;
  final BigNum maxHp;
  BigNum hp;
  final double speed;

  /// 배에 닿았을 때 접촉 1회 피해.
  final BigNum attack;

  /// 처치 골드 (화물칸·동시 처치 보너스 전).
  final BigNum gold;
  final bool boss;

  /// 돌발 이벤트 적(goldfish | merchant | ambush). 파 끝 판정에서 빠진다(Field.waveFoes).
  final String? eventKind;

  /// 잡몹 정의 (역할: 분열·부활). 보스는 null.
  final EnemyDef? def;

  /// 보스 정의 (패턴). 잡몹은 null.
  final BossDef? bossDef;

  /// 크라켄 촉수처럼 보스에 딸린 적이면 그 보스의 id.
  final int? ownerId;

  /// 무한 항해 등급 테두리 (0 없음).
  final int tier;

  /// 보호막 중 (보스 패턴).
  bool shielded = false;

  /// 다음 접촉 피해까지 남은 초. 0이면 닿자마자 때린다.
  double contactTimer = 0;

  /// 남은 기절(초). 기절 중에는 이동·접촉 공격을 하지 않는다.
  double stunTimer = 0;

  /// 등장 대기(초, 스폰 패턴 scatter): 0보다 크면 화면 밖에서 기다린다 — 움직이지도 겹침을 풀지도 않는다.
  double holdSec = 0;

  /// 부활을 이미 썼다.
  bool revived = false;

  /// 감속(이동 × (1 − slow))과 남은 초.
  double slow = 0;
  double slowTimer = 0;

  /// 받는 피해 +비율과 남은 초 (같은 종류는 큰 것 하나 — 4.8).
  double vulnerable = 0;
  double vulnerableTimer = 0;

  /// 화상: 남은 틱, 틱당 피해, 건 선원.
  int burnTicks = 0;
  BigNum burnPerTick = BigNum.zero;
  String? burnCrewId;

  bool get alive => !hp.isZero && !hp.isNegative;
  bool get stunned => stunTimer > 0;

  /// [heading]은 향하는 방향(없으면 EnemyView 기본).
  EnemyView view({double? heading}) => EnemyView(
    id: id,
    kind: kind,
    x: x,
    y: y,
    hpRatio: alive ? (hp / maxHp).toDouble() : 0,
    layer: layer,
    boss: boss,
    stunned: stunned,
    shielded: shielded,
    tier: tier,
    slowed: slowTimer > 0,
    burning: burnTicks > 0,
    vulnerable: vulnerableTimer > 0,
    heading: heading ?? EnemyView.sideHeading,
    eventKind: eventKind,
  );
}

/// 무기 슬롯 하나 (출전 선원).
class Gun {
  Gun({
    required this.crewId,
    required this.family,
    required this.power,
    required this.skill,
    this.rarity = 0,
    this.legend,
  }) : attack = family.attackAt(rarity);

  /// [crewId]의 계열·등급 사다리·스킬(선원 `skill`이 있으면 그것)로 만든다.
  factory Gun.of(GameTables t, String crewId, {required double power, int rarity = 0}) {
    final crew = t.crews.byId(crewId);
    final family = t.skills.byId(crew.family);
    final skillId = crew.skill;
    return Gun(
      crewId: crewId,
      family: family,
      power: power,
      rarity: rarity,
      skill: skillId == null ? family.skill : t.skills.skillById(skillId),
      legend: t.skills.legendFor(crewId, rarity, t.rarities.rarities.indexWhere((r) => r.id == 'legend')),
    );
  }

  final String crewId;
  final FamilyDef family;

  /// 선원 파워 (레벨 배율 × 승급 배율).
  final double power;

  /// 등급 순번 (0 = 일반). 사다리와 전설 화면 스킬을 정한다.
  final int rarity;

  /// 등급 사다리를 적용한 기본 공격.
  final AttackDef attack;
  final SkillDef skill;

  /// 전설 고유 능력 (전설 미만이면 null).
  final LegendDef? legend;

  /// 다음 발사까지 남은 초 (공격 속도 배율 적용 전 기준).
  double cooldown = 0;

  /// 다음 스킬까지 남은 초 (공격 속도 배율 적용 전 기준).
  double skillCooldown = 0;

  FleetSlot view() {
    double ratio(double left, double full) => full <= 0 ? 0.0 : (left / full).clamp(0.0, 1.0);
    return FleetSlot(
      crewId: crewId,
      cooldown: ratio(cooldown, attack.intervalSec),
      skillCooldown: ratio(skillCooldown, skill.cooldownSec),
      rarity: rarity,
    );
  }
}

/// 지속 피해 장판 (수중). 남은 시간 동안 매 틱 [perTick] × 비율의 피해.
class Zone {
  Zone({
    required this.crewId,
    required this.x,
    required this.y,
    required this.radius,
    required this.ticksLeft,
    required this.perTick,
    required this.excludeLayers,
    this.slow = 0,
    this.stunEveryTicks = 0,
    this.stunSec = 0,
  });

  final String crewId;
  final double x;
  final double y;
  final double radius;
  int ticksLeft;
  final BigNum perTick;
  final Set<String> excludeLayers;

  /// 전설 장판: 안의 적 감속, [stunEveryTicks]마다 [stunSec] 기절.
  final double slow;
  final int stunEveryTicks;
  final double stunSec;
  int age = 0;
}

/// 전투 시뮬 내부 상태. 세이브에 들어가지 않고, 매 틱 [BattleView]로 투영된다.
/// GameState.battle과 어긋나면(상태 불러오기 등) BattleSystem이 새로 만든다.
class Field {
  Field({required this.stage, required this.shipHpMax, required this.shipHp});

  final int stage;

  /// 다음에 처리할 엔진 틱. 이 값이 BattleView.tick과 다르면 다시 맞춘다.
  int tick = 0;
  final List<Foe> foes = [];
  List<Gun> guns = [];
  final List<Zone> zones = [];
  String? captainId;
  BigNum shipHpMax;
  BigNum shipHp;
  bool bossActive = false;
  int bossTicksLeft = 0;

  /// 다음 무리(또는 보스)가 올 때까지 남은 초. 적이 없을 때만 줄어든다.
  double travelLeft = 0;

  /// 적 체력 배율 (보물 바다 회차, 환생 v2 — 무리·보스 모두). battle_system이 Field를 만들 때 넣는다.
  double enemyHpScale = 1;
  int _nextId = 1;

  /// 동시 처치 창: 마지막 처치 후 남은 초, 묶인 마리 수, 묶인 골드.
  double comboTimer = 0;
  int comboKills = 0;
  BigNum comboGold = BigNum.zero;

  /// 공격 속도 버프(지원 스킬): 배율 가산값과 남은 초. 같은 종류는 큰 것 하나만 (설계서 4.8).
  double buffValue = 0;
  double buffLeft = 0;

  /// 보스 패턴 주기(보호막 재생·용암·소환)까지 남은 틱.
  int bossTimerTicks = 0;

  /// 전장 모양(탑다운). 없으면 waves.top 기본 배 반경으로 — [geometryOr].
  BattleGeometry? geometry;

  /// [geometry]를 만든 배 상태(shapeField가 바뀔 때만 다시 만든다).
  Object? shipSeen;

  /// [geometry], 없으면 waves.top 기본으로 정해 둔다(테스트·측정 장면).
  BattleGeometry geometryOr(WavesTable w) => geometry ??= TopGeometry.of(w);

  int nextId() => _nextId++;

  Iterable<Foe> get living => foes.where((f) => f.alive);

  /// 즉석 도전용(ChallengeTracker가 읽고 비운다): 궁극기로 처치한 수, 이번 틱 닫힌 동시 처치 수.
  int ultimateKills = 0;
  int multiKill = 0;

  /// 파를 이루는 살아 있는 적(돌발 이벤트 적 제외) — 파 끝·다음 파 판정.
  Iterable<Foe> get waveFoes => living.where((f) => f.eventKind == null);

  /// 이 Field가 [view]·[stage]와 그대로 이어지는가 (아니면 BattleSystem이 새로 만든다).
  bool matches(BattleView view, int stage) => tick == view.tick && this.stage == stage && bossActive == view.bossActive;

  BattleView view(BattleView prev) => BattleView(
    tick: prev.tick,
    shipHp: shipHp,
    shipHpMax: shipHpMax,
    bossActive: bossActive,
    bossTicksLeft: bossTicksLeft,
    enemies: [for (final f in living) f.view(heading: geometry?.heading(f))],
    fleet: [for (final g in guns) g.view()],
    captainId: captainId,
    hitStopTicks: prev.hitStopTicks,
    speed: prev.speed,
    stage: stage,
    chest: prev.chest,
    fever: prev.fever,
    feverTicksLeft: prev.feverTicksLeft,
    seaEvent: prev.seaEvent,
    challenge: prev.challenge,
    mode: 'top',
    shipX: geometry?.viewShip?.x,
    shipY: geometry?.viewShip?.y,
  );
}

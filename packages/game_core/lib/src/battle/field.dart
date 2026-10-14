import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_data/game_data.dart';

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

  /// 잡몹 정의 (역할: 분열·부활). 보스는 null.
  final EnemyDef? def;

  /// 다음 접촉 피해까지 남은 초. 0이면 닿자마자 때린다.
  double contactTimer = 0;

  /// 남은 기절(초). 기절 중에는 이동·접촉 공격을 하지 않는다.
  double stunTimer = 0;

  /// 부활을 이미 썼다.
  bool revived = false;

  bool get alive => !hp.isZero && !hp.isNegative;
  bool get stunned => stunTimer > 0;

  EnemyView view() => EnemyView(
    id: id,
    kind: kind,
    x: x,
    y: y,
    hpRatio: alive ? (hp / maxHp).toDouble() : 0,
    layer: layer,
    boss: boss,
    stunned: stunned,
  );
}

/// 무기 슬롯 하나 (출전 선원).
class Gun {
  Gun({required this.crewId, required this.family, required this.power, required this.skill, this.rarity = 0})
    : attack = family.attackAt(rarity);

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
  });

  final String crewId;
  final double x;
  final double y;
  final double radius;
  int ticksLeft;
  final BigNum perTick;
  final Set<String> excludeLayers;
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
  int _nextId = 1;

  /// 동시 처치 창: 마지막 처치 후 남은 초, 묶인 마리 수, 묶인 골드.
  double comboTimer = 0;
  int comboKills = 0;
  BigNum comboGold = BigNum.zero;

  /// 공격 속도 버프(지원 스킬): 배율 가산값과 남은 초. 같은 종류는 큰 것 하나만 (설계서 4.8).
  double buffValue = 0;
  double buffLeft = 0;

  int nextId() => _nextId++;

  Iterable<Foe> get living => foes.where((f) => f.alive);

  BattleView view(BattleView prev) => BattleView(
    tick: prev.tick,
    shipHp: shipHp,
    shipHpMax: shipHpMax,
    bossActive: bossActive,
    bossTicksLeft: bossTicksLeft,
    enemies: [for (final f in living) f.view()],
    fleet: [for (final g in guns) g.view()],
    captainId: captainId,
    hitStopTicks: prev.hitStopTicks,
    speed: prev.speed,
  );
}

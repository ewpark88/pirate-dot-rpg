import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_data/game_data.dart';

/// 전장의 적 하나. 시뮬 내부 값(실제 HP·접촉 타이머)을 들고, 화면에는 [EnemyView]로 나간다.
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

  /// 다음 접촉 피해까지 남은 초. 0이면 닿자마자 때린다.
  double contactTimer = 0;

  bool get alive => !hp.isZero && !hp.isNegative;

  EnemyView view() => EnemyView(
    id: id,
    kind: kind,
    x: x,
    y: y,
    hpRatio: alive ? (hp / maxHp).toDouble() : 0,
    layer: layer,
    boss: boss,
  );
}

/// 무기 슬롯 하나 (출전 선원).
class Gun {
  Gun({required this.crewId, required this.family, required this.power});

  final String crewId;
  final FamilyDef family;

  /// 선원 파워 (레벨 배율 × 승급 배율).
  final double power;

  /// 다음 발사까지 남은 초 (공격 속도 배율 적용 전 기준).
  double cooldown = 0;

  FleetSlot view() {
    final interval = family.attack.intervalSec;
    final ratio = interval <= 0 ? 0.0 : (cooldown / interval).clamp(0.0, 1.0);
    return FleetSlot(crewId: crewId, cooldown: ratio);
  }
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

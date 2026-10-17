import 'package:game_core/src/battle/beam.dart' show Beam;
import 'package:game_core/src/battle/fast_sail.dart' show FastSailRun;
import 'package:game_core/src/battle/flight.dart';
import 'package:game_core/src/battle/foe.dart';
import 'package:game_core/src/battle/gun.dart';
import 'package:game_core/src/battle/shield.dart';
import 'package:game_core/src/battle/topdown/geometry.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/battle/topdown/top_threat.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_data/game_data.dart';

export 'package:game_core/src/battle/foe.dart';
export 'package:game_core/src/battle/gun.dart';

export 'package:game_core/src/battle/topdown/geometry.dart' show geometryFor, shapeField;
export 'package:game_core/src/battle/topdown/top_threat.dart' show EnemyShot, TopdownStep;

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

  /// 반사(보스 특성 reflect)가 이번 틱([reflectTick])에 배에 준 피해 — maxShipHpPerSec 상한을 틱마다 센다.
  BigNum reflected = BigNum.zero;
  int reflectTick = -1;

  /// 배 고정(OpSetShipStill): 순항을 끈다 — 미리보기 같은 보여 주기 장면.
  bool shipStill = false;
  BigNum shipHp;
  bool bossActive = false;
  int bossTicksLeft = 0;

  double travelLeft = 0; // 다음 무리(또는 보스)가 올 때까지 남은 초. 적이 없을 때만 줄어든다

  int rebirths = 0; // 환생 횟수 — 나오는 무리 종 수(regions.speciesUnlock). Field를 만들 때 넣는다
  double enemyHpScale = 1; // 적 체력 배율(보물 바다 회차, 환생 v2 — 무리·보스). Field를 만들 때 넣는다
  int _nextId = 1;

  /// 동시 처치 창: 마지막 처치 후 남은 초, 묶인 마리 수, 묶인 골드.
  double comboTimer = 0;
  int comboKills = 0;
  BigNum comboGold = BigNum.zero;

  /// 공격 속도 버프(지원 스킬): 배율 가산값과 남은 초. 같은 종류는 큰 것 하나만 (설계서 4.8).
  double buffValue = 0;
  double buffLeft = 0;

  /// 선원별 실제 피해(남은 HP로 자름, 선원 몫만 — 피버 오라·자폭·빠른 항해 제외, 사용자 피드백 #13·#14).
  /// [crewDamage]는 이번 스테이지(Field가 새로 생기면 0), [bossDamage]는 이번 보스전(보스·분열 몸·촉수, startBoss에서 비움).
  final crewDamage = <String, BigNum>{};
  final bossDamage = <String, BigNum>{};

  void creditDamage(String crewId, Foe e, BigNum dealt) {
    crewDamage[crewId] = (crewDamage[crewId] ?? BigNum.zero) + dealt;
    if (bossActive && (e.boss || e.ownerId != null)) bossDamage[crewId] = (bossDamage[crewId] ?? BigNum.zero) + dealt;
  }

  /// 보스전 MVP: 보스 피해가 가장 큰 선원(같으면 출전 칸 앞). 없으면 null.
  String? get bossMvp {
    String? best;
    for (final g in guns) {
      final d = bossDamage[g.crewId];
      if (d != null && (best == null || d > bossDamage[best]!)) best = g.crewId;
    }
    return best;
  }

  int bossTimerTicks = 0; // 보스 패턴 주기(보호막 재생·용암·소환)까지 남은 틱

  BattleGeometry? geometry; // 전장 모양(탑다운). 없으면 waves.top 기본 — geometryOr

  final List<EnemyShot> enemyShots = [];
  final List<Flight> flights = [];
  final List<Beam> beams = []; // 유지되는 레이저 빔(beam.dart)
  ShipShield? shield; // 배 흡수막(shield.dart)
  final List<({double x, double y, double r, int until})> inks = []; // 먹물 구름(조준 가림, 도감 v2)
  FastSailRun?
  fastSail; // 빠른 항해 돌파 구간(fast_sail.dart) // 날아가는 선원 탄(선원 개성 v2, flight.dart) // 날아가는 적 탄(배 위협 (a)) — 도착하면 배 피해

  ({String bossId, int tier})? bounty; // 진행 중인 현상금 전투(top_bounty.dart), 타이머는 bossTicksLeft
  TowerRun? tower; // 진행 중인 탑(top_tower.dart)
  RushRun? rush; // 진행 중인 보스 러시(top_rush.dart)
  DungeonRun? dungeon; // 진행 중인 요일 던전(top_dungeon.dart)
  List<String>? sceneFleet; // 장면 중 임시 출전(요일 던전 — 세이브 fleet는 그대로)
  String? scenePattern; // 장면 무리 파의 자리 패턴(요일 던전: arc·ring·scatter…)
  double speedHpMul = 1; // 유료 2배속 중 적 HP 배율(공격은 역수, iap purchasedSpeedHpMul — 진행 1.5배)
  int feverMobKills = 0; // 이번 틱에 잡은 피버 고리 적(게이지에서 뺌 — battle_system)
  int hordeCount = 0; // 다음 무리 파가 대군 습격이면 마리 수(nextEncounter — spawnWaveFoes)
  double poolScale = 1; // 다음 무리 파의 몫 배율(피버 보충 고리 fever.swarm.refillPool — spawnWaveFoes)
  int slotsOpen = 0; // 열린 출전 칸(fleetSlots — 화면 잠금 칸 판정, BattleView.slotsOpen)
  double sceneHpMul = 1; // 장면 적 체력 배율(요일 던전 묶음 hpMul — 무리·보스)
  bool scenePooled = false; // 장면 무리 파도 평소 파처럼 한 파 몫(HP·공격·골드)을 마리 수로 나눈다(요일 던전)

  /// 본 전투를 멈춘 장면 모드(현상금·탑 — scene_mode.dart) 중인가.
  bool get inScene => bounty != null || tower != null || rush != null || dungeon != null;

  Object? shipSeen; // [geometry]를 만든 배 상태(shapeField가 바뀔 때만 다시 만든다)

  /// [geometry], 없으면 waves.top 기본(테스트·측정 장면).
  BattleGeometry geometryOr(WavesTable w) => geometry ??= TopGeometry.of(w);

  int nextId() => _nextId++;

  Iterable<Foe> get living => foes.where((f) => f.alive);

  /// 배가 [raw]만큼 맞고 (보호막을 뺀) 깎인 양을 돌려준다. 한 대는 최대 HP × [capRatio](waves.shipHitCap)까지 — 한 대에 가라앉지 않게.
  BigNum hurtShip(BigNum raw, double capRatio) {
    final cap = shipHpMax.times(capRatio);
    final guarded = bossActive && bossGuard > 0 ? raw.times(1 - bossGuard) : raw; // 철갑판(상점 bossTime)
    var amount = guarded > cap ? cap : guarded;
    final s = shield; // 보호막이 먼저 받는다(개성 v2 7.1)
    if (s != null && !s.hp.isZero) {
      final absorbed = amount > s.hp ? s.hp : amount;
      s.hp = s.hp - absorbed;
      amount = amount - absorbed;
    }
    final hp = shipHp - amount;
    shipHp = hp.isNegative ? BigNum.zero : hp;
    return amount;
  }

  /// 즉석 도전용: 이번 틱 동시 처치 수 (ChallengeTracker가 읽고 비운다).
  int multiKill = 0;

  /// 보스전·현상금에서 배가 받는 피해 감소 비율(보물지도 상점 철갑판, rebirth_shop bossGuard). BattleSystem이 넣는다.
  double bossGuard = 0;

  /// 자동 보스 도전(spawner.dart autoBossTick): 실패 뒤 파밍 틱 · 실패 때 배 부위 레벨 합 · 재도전까지 남은 틱.
  int farmTicks = 0;
  int autoBossLeft = 0;
  double failPower = 0;
  double failNeed = 1;
  bool retryWinnable = false;

  /// 피버 무리(meta.fever.swarm, 사용자 폰 피드백 2026-10-17): null이 아니면 다음 무리 파가 countMul배, 자리는 이 패턴(ring = 사방에서 한꺼번에).
  /// BattleSystem이 파를 부르기 전에 넣고 끝나면 지운다.
  String? feverSwarm;

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
    autoBossTicksLeft: autoBossLeft,
    slotsOpen: slotsOpen,
    retryWinnable: retryWinnable,
    seaEvent: prev.seaEvent,
    challenge: prev.challenge,
    mode: 'top',
    bounty: bounty == null ? null : BountyView(bossId: bounty!.bossId, tier: bounty!.tier, ticksLeft: bossTicksLeft),
    tower: tower == null ? null : TowerView(floor: tower!.floor, wave: tower!.wave, waves: tower!.waves),
    rush: rush == null ? null : RushView(index: rush!.index, total: rush!.bosses.length, ticks: rush!.ticks),
    dungeon: dungeon == null
        ? null
        : DungeonView(group: dungeon!.group, step: dungeon!.step, wave: dungeon!.wave, waves: dungeon!.waves),
    shipX: geometry?.viewShip?.x,
    shipY: geometry?.viewShip?.y,
    shipHeading: switch (geometry) {
      final TopGeometry g => g.shipHeading,
      _ => 0,
    },
    shipShield: shield?.ratio ?? 0,
    fastSail: fastSail?.view(),
    crewDamage: crewDamage.isEmpty ? const {} : Map.unmodifiable(crewDamage),
  );
}

/// 탑 한 판의 진행(전장에만 — 세이브엔 tower.active.floor만). [wave] 1부터, [boss] = 이 층 보스가 나왔다, [spawned] = 나온 적 수(처치 수 계산).
class TowerRun {
  TowerRun({required this.floor, required this.waves});

  int floor;
  int wave = 0;
  final int waves;
  bool boss = false;
  int spawned = 0;
  int floorTicks = 0; // 이 층에서 지난 틱(floorTimeLimitSec)
}

/// 보스 러시 한 판의 진행(전장에만 — 세이브엔 rush.active {index, ticks}).
class RushRun {
  RushRun({required this.bosses, this.index = 0, this.ticks = 0});

  final List<String> bosses;
  int index;
  int ticks;
}

/// 요일 던전 한 판의 진행(전장에만 — 세이브엔 dungeon.active {group, step}).
class DungeonRun {
  DungeonRun({required this.group, required this.step, required this.waves});

  final String group;
  final int step;
  final int waves;
  int wave = 0;
  bool boss = false;
  int ticks = 0; // 이 단계에서 지난 틱(stepTimeLimitSec)
}

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
  BigNum shipHp;
  bool bossActive = false;
  int bossTicksLeft = 0;

  double travelLeft = 0; // 다음 무리(또는 보스)가 올 때까지 남은 초. 적이 없을 때만 줄어든다

  double enemyHpScale = 1; // 적 체력 배율(보물 바다 회차, 환생 v2 — 무리·보스). Field를 만들 때 넣는다
  int _nextId = 1;

  /// 동시 처치 창: 마지막 처치 후 남은 초, 묶인 마리 수, 묶인 골드.
  double comboTimer = 0;
  int comboKills = 0;
  BigNum comboGold = BigNum.zero;

  /// 공격 속도 버프(지원 스킬): 배율 가산값과 남은 초. 같은 종류는 큰 것 하나만 (설계서 4.8).
  double buffValue = 0;
  double buffLeft = 0;

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

  Object? shipSeen; // [geometry]를 만든 배 상태(shapeField가 바뀔 때만 다시 만든다)

  /// [geometry], 없으면 waves.top 기본(테스트·측정 장면).
  BattleGeometry geometryOr(WavesTable w) => geometry ??= TopGeometry.of(w);

  int nextId() => _nextId++;

  Iterable<Foe> get living => foes.where((f) => f.alive);

  /// 배가 [raw]만큼 맞고 (보호막을 뺀) 깎인 양을 돌려준다. 한 대는 최대 HP × [capRatio](waves.shipHitCap)까지 — 한 대에 가라앉지 않게.
  BigNum hurtShip(BigNum raw, double capRatio) {
    final cap = shipHpMax.times(capRatio);
    var amount = raw > cap ? cap : raw;
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

  /// 피버 무리(meta.fever.swarm, 사용자 폰 피드백 2026-10-17): 켜져 있으면 다음 무리 파가 countMul배·사방에서 한꺼번에. BattleSystem이 파를 부르기 전에 넣는다.
  bool feverSwarm = false;

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
    bounty: bounty == null ? null : BountyView(bossId: bounty!.bossId, tier: bounty!.tier, ticksLeft: bossTicksLeft),
    shipX: geometry?.viewShip?.x,
    shipY: geometry?.viewShip?.y,
    shipHeading: switch (geometry) {
      final TopGeometry g => g.shipHeading,
      _ => 0,
    },
    shipShield: shield?.ratio ?? 0,
    fastSail: fastSail?.view(),
  );
}

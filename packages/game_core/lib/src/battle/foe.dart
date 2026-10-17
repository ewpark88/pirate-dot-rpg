import 'package:game_core/src/battle/topdown/boss_patterns.dart' show BossPlan;
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
    this.bossDef,
    this.ownerId,
    this.tier = 0,
    this.eventKind,
    this.passX,
    this.passY,
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
  BigNum attack; // 분노(보스 특성 enrage)가 키운다

  /// 처치 골드 (화물칸·동시 처치 보너스 전).
  final BigNum gold;
  final bool boss;

  /// 돌발 이벤트 적(goldfish | merchant | ambush). 파 끝 판정에서 빠진다(Field.waveFoes).
  final String? eventKind;

  /// 스쳐 지나가는 방향(단위 벡터, 보물 상선). 있으면 배로 오지 않고 이 방향으로 speed 그대로 직진 — 겹침 풀기·밀기·접촉 없음(TopGeometry).
  final double? passX;
  final double? passY;

  /// 잡몹 정의 (역할: 분열·부활). 보스는 null.
  final EnemyDef? def;

  /// 보스 정의 (패턴). 잡몹은 null.
  final BossDef? bossDef;

  /// 크라켄 촉수처럼 보스에 딸린 적이면 그 보스의 id.
  int? ownerId; // 호위(보스 특성 escort)는 소환 뒤 넣는다

  /// 무한 항해 등급 테두리 (0 없음).
  final int tier;

  /// 보호막 중(보스 패턴) · 다음 접촉 피해까지 남은 초(0 = 닿자마자) · 남은 기절 초(기절 중 이동·접촉 공격 없음).
  bool shielded = false;
  double contactTimer = 0;
  double _stun = 0;
  double get stunTimer => _stun;
  set stunTimer(double v) {
    if (vanguard && v > _stun) return; // 돌격대는 기절이 늘지 않는다
    if (boss && v > _stun) breakStun += v - _stun; // 보스 브레이크 게이지(boss_break.dart)
    _stun = v;
  }

  /// 보스 브레이크(사용자 결정 2026-10-17)에 쌓일 이번 틱 제어량: 기절·둔화·취약 늘어난 초, 밀림·끌림 거리. 게이지 0~1, 쓰러진 끝 틱.
  double breakStun = 0;
  double breakSlow = 0;
  double breakVulnerable = 0;
  double breakPull = 0;
  double breakGauge = 0;
  int brokenUntil = 0;

  /// 보스 특성 타이머(boss_traits.dart): reflectAt·reflectUntil·dashAt·dashUntil·escorts(소환한 차례 수) 틱/횟수, 분노했나.
  final traitTicks = <String, int>{};
  bool enraged = false;
  int breakCooldownUntil = 0; // 일어난 뒤 이 틱까지 게이지가 안 쌓인다(bossBreak.cooldownSec)
  int breakCooldownTicks = 0; // 그 쿨다운 전체 길이
  double breakCooldownRatio = 0; // 남은 비율(EnemyView.breakCooldown) — tickBossBreak가 갱신

  /// 돌격대(waves.top.vanguard, S1·S2): 넉백·기절·끌기 면역, 무리 사이를 뚫고 배로 곧장 — EnemyView.vanguard.
  bool vanguard = false;

  /// 도감 v2: 분열한 횟수(BossDef.splitAt 중 쓴 수) · 자폭 적이 이미 터졌나.
  int splits = 0;
  bool exploded = false;

  /// 등장 대기(초, 스폰 패턴 scatter·가까이 등장): 0보다 크면 기다린다 — 움직이지도·조준되지도·겹침을 풀지도 않는다.
  double holdSec = 0;

  /// 배 위협(top_threat.dart): (b) 솟아오를 자리 nearX·Y·예고를 냈나 warned, (a) 원거리 다음 발사까지 fireTimer초.
  double? nearX;
  double? nearY;
  bool warned = false;
  double fireTimer = 0;

  /// 보스 기본 포탄 예고(EnemyWindup)용 — 지난 틱에 본 접촉 타이머(이번 틱 값과 비교해 예고 시점을 지났나 본다).
  double seenContact = double.infinity;
  int swayDir = 1; // 큰 보스가 배 위 호를 오가는 방향(+1 시계·−1)
  double scale = 1; // 보스 크기 배율(waves.top.bossScale) — 충돌 반경·standoff·원 돌기(TopField)
  BossPlan? plan; // 보스 행동 v2 패턴 상태(boss_patterns.dart) — 패턴이 있는 보스·바다 괴물
  bool get standsOff => boss || plan != null; // standoff 원에 서서 돈다(보스·패턴 있는 이벤트 적)
  bool get emerging => warned && holdSec > 0;

  bool revived = false; // 부활을 이미 썼다

  /// 물기 속박(bara, crew_traits2.dart) 남은 초 — 그동안 움직이지 않는다(공격은 한다).
  double rootTimer = 0;

  /// 감속(이동 × (1 − slow))과 남은 초.
  double slow = 0;
  double _slowTimer = 0;
  double get slowTimer => _slowTimer;
  set slowTimer(double v) {
    if (boss && v > _slowTimer) breakSlow += v - _slowTimer;
    _slowTimer = v;
  }

  /// 받는 피해 +비율과 남은 초 (같은 종류는 큰 것 하나 — 4.8).
  double vulnerable = 0;
  double _vulnerableTimer = 0;
  double get vulnerableTimer => _vulnerableTimer;
  set vulnerableTimer(double v) {
    if (boss && v > _vulnerableTimer) breakVulnerable += v - _vulnerableTimer;
    _vulnerableTimer = v;
  }

  /// 화상: 남은 틱, 틱당 피해, 건 선원.
  int burnTicks = 0;
  BigNum burnPerTick = BigNum.zero;
  String? burnCrewId;

  bool get alive => !hp.isZero && !hp.isNegative;
  bool get stunned => stunTimer > 0;

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
    emerging: emerging,
    vanguard: vanguard,
    breakRatio: boss ? breakGauge : 0,
    broken: brokenUntil > 0,
    breakCooldown: boss ? breakCooldownRatio : 0,
    rooted: rootTimer > 0,
    eventKind: eventKind,
  );
}

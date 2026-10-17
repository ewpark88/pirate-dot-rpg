import 'dart:math' as math;

import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/targeting.dart' show Volley;
import 'package:game_core/src/battle/topdown/top_duel.dart';
import 'package:game_core/src/battle/topdown/top_fever.dart' show feverForwardBoost, feverPose;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/economy/fever.dart' show feverOn;
import 'package:game_core/src/economy/rebirth_shop.dart' show bossGuard;
import 'package:game_core/src/economy/ship_stats.dart' show partLook;
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 점 하나.
typedef Point = ({double x, double y});

/// 전장의 '모양': 적이 어디서 나와 어디로 가고, 누가 사거리 안인가 (탑다운 전환 T1).
/// 피해 공식·스킬·보스 패턴·보상은 모드와 상관없이 공용 코드(combat·skills·bosses)가 그대로 하고, 위치에 관한 것만 이것에 묻는다.
/// 구현은 TopGeometry(top_geometry.dart, 위에서 내려다본 2D, 배 중심 고정) 하나 — 옆모습은 T4-2에서 삭제(사용자 결정 2026-10-15).
abstract interface class BattleGeometry {
  /// BattleView.mode (`top`).
  String get mode;

  /// 배 위치(배 대상 스킬의 연출 위치).
  Point get ship;

  /// 화면 전체 공격(궁극기·전설 화면 스킬)의 중심.
  Point get center;

  /// 보이는 화면 안인가 — 그 밖의 적은 맞히지 않는다.
  bool onScreen(Foe e);

  /// [a]가 맞힐 수 있는 적(사거리 + [reachBonus], 화면 안, 층 제외).
  List<Foe> eligible(AttackDef a, List<Foe> foes, {double reachBonus = 0});

  /// [n]발을 서로 다른 대상에 (맞힐 적이 적으면 있는 만큼).
  List<Volley> aimMany(AttackDef a, int n, List<Foe> foes, Rng rng, {double reachBonus = 0});

  /// 무리 한 파를 [f]에 더한다(수치는 spawner와 같고 위치만 모드마다).
  void spawnWave(Field f, int stage, SystemContext ctx, {int? count, String? kind});

  /// spawner.startBoss가 만든 보스·촉수를 이 모드의 자리로. 상태 불러오기면 [x]·[y]를 이어받는다.
  void placeBoss(Field f, {double? x, double? y});

  /// [e]를 한 틱 움직인다. 이미 배에 닿아 있으면(이번 틱에 공격할 수 있으면) true.
  bool advance(Foe e, double speed, double dt);

  /// 틱 끝 정리(겹침 풀기, 보스 원 돌기).
  void settle(Field f, double dt);

  /// 밀어내기(배에서 멀어지는 쪽으로 [distance]).
  void push(Foe e, double distance);

  /// 점 ([x],[y]) 쪽으로 [amount]만큼 끌어당김(음수면 밀어냄). 지나치지 않는다.
  void pull(Foe e, double x, double y, double amount);

  /// [a]가 남기는 장판(수중)의 반지름.
  double zoneRadius(AttackDef a);

  /// 분열한 작은 적 [n]마리 중 [i]번째 자리.
  Point splitAt(Foe parent, int i, int n);

  /// [e]가 향하는 방향(라디안, atan2(dy, dx)) — 렌더가 그림을 돌린다.
  double? heading(Foe e);

  /// BattleView.shipX·shipY로 낼 배 중심.
  Point? get viewShip;

  /// 조준점 ([tx],[ty])으로 쏘는 포구와 방향(AttackFired.fromX·fromY·angle).
  ({double x, double y, double angle})? muzzle(double tx, double ty);
}

/// 전장 모양(탑다운). 배 반경 = 배 등급(ship_tiers topRadius). 선체 캡슐 = 배율 1 선체(ship_tiers topHalfWidth·topHullBow·topHullStern)
/// × 그리기 배율 `waves.top.shipScale` × 선체 강화 단계 [hullStage]의 커짐(`waves.top.hullGrow` 폭·뱃머리·배꼬리, 단계당 1 + g·(단계−1))
/// — 렌더와 같은 키·같은 그림 기준이라 어긋나지 않는다(apps/game/test/render/ship_hitbox_test.dart가 지킨다).
BattleGeometry geometryFor(GameTables t, int stage, {int hullStage = 1}) {
  final tier = t.shipTiers.tierAt(stage);
  final top = t.waves.raw.obj('top');
  final scale = top.numberOr('shipScale', 1);
  final grow = top.has('hullGrow') ? top.obj('hullGrow') : null;
  final k = math.max(0, hullStage - 1);
  double g(String key) => 1 + (grow == null ? 0.0 : grow.numberOr(key, 0)) * k;
  final bow = tier.topHullBow * scale * g('bow');
  final stern = tier.topHullStern * scale * g('stern');
  return TopGeometry.of(
    t.waves,
    shipRadius: tier.topRadius,
    hullHalfWidth: tier.topHalfWidth * scale * g('width'),
    hullHalfLength: (bow + stern) * half,
    hullOffset: (stern - bow) * half,
  );
}

/// [f]에 지금 배(등급·선체 강화 단계)에 맞는 모양을 둔다. 배 상태가 바뀔 때만 다시 만든다 — 강화해도 무리는 그대로.
/// 돌발 이벤트 '폭풍'이면 적 이동 배율(meta.seaEvents 폭풍 enemySpeed)도 매번 맞춘다.
void shapeField(Field f, GameState s, GameTables t) {
  f.bossGuard = bossGuard(s, t); // 보물지도 상점 철갑판(보스전·현상금 배 피해 감소)
  if (f.geometry == null || !identical(f.shipSeen, s.ship)) {
    if (f.shipSeen != null) _refreshHull(f, s, t); // 배를 강화했다(전장을 처음 만들 때는 이미 맞다)
    final old = f.geometry;
    f
      ..shipSeen = s.ship
      ..geometry = geometryFor(t, s.progress.stage, hullStage: partLook(s, t)['hull'] ?? 1);
    final g = f.geometry;
    if (old is TopGeometry && g is TopGeometry) {
      // 강화해도 좌우 이동·비켜선 자리가 끊기지 않게
      g
        ..weaveTick = old.weaveTick
        ..weave(old.top.shipX - old.base.shipX, dy: old.top.shipY - old.base.shipY, heading: old.shipHeading);
      TopDuel.carry(old, g);
    }
  }
  final g = f.geometry;
  if (g is TopGeometry) {
    final on = feverOn(s) || f.fastSail != null; // 빠른 항해 돌파도 피버처럼 전진·좌우
    g
      ..speedScale =
          seaEventSpeed(s, t) *
          feverApproach(s, t) // 피버 무리는 빨리 조여 온다
      ..forwardBoost = feverForwardBoost(s, t.meta.raw.obj('fever').raw, on: on)
      ..weaveTick = on ? g.weaveTick + 1 : 0;
    final free = feverPose(s, t, g.weaveTick, on: on);
    final duel = TopDuel.of(t.waves); // 보스전 비켜서기(사용자 피드백 #10), 표 키 없으면 피버 자리 그대로
    g.pose(duel == null ? free : duel.step(f, g, free, dt: t.waves.tickMs * secondsPerMillisecond));
  }
}

/// 선체 강화가 바로 먹게(S1 '강화했는데 그대로' 버그): 배 체력 최대를 새로 정하고, 늘어난 만큼 지금 체력도 더한다(줄면 최대로 자름).
void _refreshHull(Field f, GameState s, GameTables t) {
  final max = CombatStats.of(s, t).shipHp;
  final grown = max - f.shipHpMax;
  if (grown.isZero) return;
  final hp = grown.isNegative ? f.shipHp : f.shipHp + grown;
  f
    ..shipHpMax = max
    ..shipHp = hp > max ? max : hp;
}

/// 지금 돌발 이벤트의 적 이동 배율(meta.seaEvents 그 이벤트의 enemySpeed, 없으면 1).
double seaEventSpeed(GameState s, GameTables t) {
  final id = s.battle?.seaEvent?.id;
  if (id == null) return 1;
  for (final e in t.meta.raw.obj('seaEvents').objs('events')) {
    if (e.str('id') == id) return e.numberOr('enemySpeed', 1);
  }
  return 1;
}

/// 피버 중 적 접근 배율(meta.fever.swarm.approachMul, 없으면 1) — 화면 밖 고리에서 피버 10초 안에 배까지 조여 오게.
double feverApproach(GameState s, GameTables t) {
  if (!feverOn(s)) return 1;
  final f = t.meta.raw.obj('fever');
  return f.has('swarm') ? f.obj('swarm').numberOr('approachMul', 1) : 1;
}

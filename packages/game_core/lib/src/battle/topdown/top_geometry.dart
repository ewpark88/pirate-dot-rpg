import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show spawnWaveFoes;
import 'package:game_core/src/battle/targeting.dart' show Volley;
import 'package:game_core/src/battle/topdown/geometry.dart';
import 'package:game_core/src/battle/topdown/top_aim.dart';
import 'package:game_core/src/battle/topdown/top_field.dart';
import 'package:game_core/src/battle/topdown/top_spawn.dart';
import 'package:game_core/src/battle/topdown/top_sway.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 탑다운: 배 중심 고정, 적은 사방에서 무리로 다가오고, 보스는 배 둘레 원을 돈다 (탑다운 전환 T1).
class TopGeometry implements BattleGeometry {
  TopGeometry(this.w, this.top) : base = top, _aim = TopAim(top, w), _spawn = TopSpawn(top, w.field.spawnSpacing);

  /// `waves.json`의 `top` 절로. [shipRadius]가 있으면 배 반경만 그것으로(배 등급별 크기).
  factory TopGeometry.of(
    WavesTable w, {
    double? shipRadius,
    double? hullHalfWidth,
    double? hullHalfLength,
    double hullOffset = 0,
  }) => TopGeometry(
    w,
    TopField.of(w).withShipRadius(shipRadius, halfWidth: hullHalfWidth, halfLength: hullHalfLength, offset: hullOffset),
  );

  final WavesTable w;

  /// 지금 배 자리의 전장 값 — 피버 좌우 이동이면 [base](바다 가운데)에서 배만 옮긴 사본([weave]).
  TopField top;
  final TopField base;

  /// 피버 좌우 이동 진행 틱(shapeField가 센다) · 배 방향(라디안, 0 위·시계 — BattleView.shipHeading).
  int weaveTick = 0;
  double shipHeading = 0;

  void pose(({double x, double y, double heading}) p) => weave(p.x, dy: p.y, heading: p.heading);
  TopAim get targeting => _aim; // 조준(먹물 구름 blinds를 보스 패턴이 정한다)

  /// 배 중심을 바다 가운데에서 ([dx], [dy])만큼 옮기고 [heading]으로 기울인다(조준·접근·캡슐·오라·사거리가 모두 따라간다).
  void weave(double dx, {double dy = 0, double heading = 0}) {
    shipHeading = heading;
    final x = base.shipX + dx;
    final y = base.shipY + dy;
    if (x == top.shipX && y == top.shipY) return;
    top = base.withShipAt(x, y);
    _aim.top = top;
    _spawn.top = top;
  }

  final TopAim _aim;
  final TopSpawn _spawn;

  /// 적 이동 배율(돌발 이벤트 '폭풍' enemySpeed 등 — shapeField가 매 틱 정한다). 보스 포함.
  double speedScale = 1;

  /// 피버 전진(feverForwardBoost): 배 앞쪽(위)에서 오는 적의 접근 배율 1 + 이 값 × (위쪽 성분). shapeField가 매 틱 정한다.
  double forwardBoost = 0;

  @override
  String get mode => 'top';

  @override
  Point get ship => (x: top.shipX, y: top.shipY);

  @override
  Point get center => ship;

  @override
  bool onScreen(Foe e) => _aim.onScreen(e);

  @override
  List<Foe> eligible(AttackDef a, List<Foe> foes, {double reachBonus = 0}) =>
      _aim.eligible(a, foes, reachBonus: reachBonus);

  List<Foe> beamHits(AttackDef a, double ux, double uy, List<Foe> foes) => _aim.beamHits(a, ux, uy, foes);

  @override
  List<Volley> aimMany(AttackDef a, int n, List<Foe> foes, Rng rng, {double reachBonus = 0}) =>
      _aim.aimMany(a, n, foes, rng, reachBonus: reachBonus);

  /// 배 위협 (b) 가까이 등장: 한 파의 ratio만큼을 배 몸통에서 distanceMin~Max 자리에 솟아오르게(예고 warnSec).
  /// 절반은 파 시작, 절반은 파 도중(0~midDelayMaxSec 뒤). 그때까지는 스폰 자리(화면 밖)에서 기다린다.
  void _nearSpawn(List<Foe> added, Rng rng) {
    final ns = top.nearSpawn;
    if (ns == null) return;
    final pool = [
      for (final e in added)
        if (!e.boss && e.ownerId == null) e,
    ];
    final n = (pool.length * ns.ratio).round();
    for (var i = 0; i < n && pool.isNotEmpty; i++) {
      final e = pool.removeAt(rng.nextInt(pool.length));
      final angle = _spawn.heading(rng);
      final ux = math.cos(angle);
      final uy = math.sin(angle);
      final d = _touchDist(ux, uy, gap: ns.distanceMin + rng.nextDouble() * (ns.distanceMax - ns.distanceMin));
      final delay = i.isOdd ? rng.nextDouble() * ns.midDelayMaxSec : 0.0;
      e
        ..nearX = top.shipX + ux * d
        ..nearY = top.shipY + uy * d
        ..holdSec = delay + ns.warnSec
        ..warned = false;
    }
  }

  /// 배 둘레 → [e] 가장자리.
  double edge(Foe e) => _aim.edge(e);

  /// 수치·종류는 spawnWaveFoes가 만들고, 자리·대열·등장 시각은 스폰 패턴(TopSpawn: swarm·scatter·arc)이 정한다.
  @override
  void spawnWave(Field f, int stage, SystemContext ctx, {int? count, String? kind}) {
    final before = f.foes.length;
    spawnWaveFoes(f, stage, ctx, count: count, kind: kind);
    final added = f.foes.sublist(before);
    _spawn.arrange(added, ctx.rng, pattern: count == null ? f.feverSwarm : f.scenePattern); // 장면 무리는 장면 패턴
    _nearSpawn(added, ctx.rng);
  }

  /// 보스는 배 위쪽, 출발 원(bossSpawnRadius) 바로 밖에서 나온다. 촉수는 보스가 설 원 위에 고르게(보스 자리 빼고).
  @override
  void placeBoss(Field f, {double? x, double? y}) {
    final boss = f.foes.where((e) => e.boss).lastOrNull;
    if (boss == null) return;
    const up = -math.pi * half;
    if (x != null && y != null) {
      boss
        ..x = x
        ..y = y;
    } else {
      _spawn.place(boss, up, top.bossSpawnRadius + top.bossRadius);
    }
    final arms = f.foes.where((e) => e.ownerId == boss.id).toList();
    for (var i = 0; i < arms.length; i++) {
      _spawn.place(arms[i], up + (i + 1) * turn / (arms.length + 1), top.bossStandoff);
    }
  }

  /// 배(보스는 standoff 원)까지 다가간다. approachRadius 밖에서는 해류로 빠르게.
  @override
  bool advance(Foe e, double speed, double dt) {
    final px = e.passX;
    if (px != null) {
      // 스쳐 지나가는 배(보물 상선): 배로 오지 않고 정해진 방향으로 곧게 — 배율 없음(S2가 화면을 건너는 시간으로 속도를 정함).
      e
        ..x += px * e.speed * dt
        ..y += (e.passY ?? 0) * e.speed * dt;
      return false;
    }
    if (e.holdSec > 0) {
      e.holdSec -= dt; // 스폰 패턴 scatter: 아직 나오지 않음
      return false;
    }
    final dx = e.x - top.shipX;
    final dy = e.y - top.shipY;
    final d = math.sqrt(dx * dx + dy * dy);
    if (e.standsOff ? d <= top.standoffOf(e) : _touching(e.x, e.y)) return true;
    final ahead = forwardBoost > 0 && dy < 0 ? 1 + forwardBoost * (-dy / d) : 1.0; // 피버 전진
    final step =
        speed *
        dt *
        speedScale *
        ahead *
        (d > top.approachRadius ? top.approachBoost : 1) *
        (e.standsOff ? 1 : top.mobSpeedScale);
    // 잡몹은 선체 몸통(캡슐)에 닿는 곳까지, 보스는 standoff 원까지.
    final near = top.hullHalfLength + top.hullOffset.abs() + top.mobRadius; // 이보다 멀면 몸통에 닿을 수 없다(탐색 생략)
    final nd = e.standsOff
        ? math.max(top.standoffOf(e), d - step)
        : (d - step > near ? d - step : math.max(_touchDist(dx / d, dy / d), d - step));
    e
      ..x = top.shipX + dx / d * nd
      ..y = top.shipY + dy / d * nd;
    return false;
  }

  /// 선체 캡슐 몸통에서 점까지(음수 = 몸통 안). 축은 배 중심을 지나는 세로선.
  double hullGap(double x, double y) {
    final reach = math.max(0, top.hullHalfLength - top.hullHalfWidth);
    final hy = top.shipY + top.hullOffset; // 캡슐 중심
    final cy = (y - hy).clamp(-reach, reach).toDouble();
    final dx = x - top.shipX;
    final dy = y - hy - cy;
    return math.sqrt(dx * dx + dy * dy) - top.hullHalfWidth;
  }

  bool _touching(double x, double y) => hullGap(x, y) <= top.mobRadius;

  /// 배 중심에서 방향 ([ux],[uy])으로 갈 때 잡몹이 몸통에 닿는(가장자리 사이 [gap]) 거리(이분 탐색).
  double _touchDist(double ux, double uy, {double gap = 0}) {
    var lo = 0.0;
    var hi = top.hullHalfLength + top.hullOffset.abs() + top.hullHalfWidth + top.mobRadius + gap;
    for (var i = 0; i < top.mobRadius.ceil() * top.mobRadius.ceil(); i++) {
      final mid = (lo + hi) * half;
      if (hullGap(top.shipX + ux * mid, top.shipY + uy * mid) <= top.mobRadius + gap) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo; // 닿는 쪽 — 다음 틱 _touching이 참이어야 접촉 공격을 한다
  }

  /// 겹친 잡몹 풀기(배 둘레 안으로는 밀지 않음), 원에 닿은 보스는 원을 따라 돈다.
  @override
  void settle(Field f, double dt) {
    final mobs = [
      for (final e in f.foes)
        if (e.alive && !e.standsOff && !e.vanguard && e.ownerId == null && e.holdSec <= 0 && e.passX == null) e,
    ];
    final min = top.mobRadius / half;
    for (var i = 0; i < mobs.length; i++) {
      final a = mobs[i];
      for (var j = i + 1; j < mobs.length; j++) {
        final b = mobs[j];
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final d2 = dx * dx + dy * dy;
        if (d2 >= min * min || d2 == 0) continue;
        final d = math.sqrt(d2);
        final p = (min - d) * top.separation * half;
        a
          ..x -= dx / d * p
          ..y -= dy / d * p;
        b
          ..x += dx / d * p
          ..y += dy / d * p;
      }
    }
    for (final e in mobs) {
      final d = _dist(e);
      if (d > 0 && hullGap(e.x, e.y) < top.mobRadius) {
        _spawn.place(e, _angle(e), _touchDist((e.x - top.shipX) / d, (e.y - top.shipY) / d));
      }
    }
    orbitBosses(top, f.foes, dt, _spawn.place); // 원 돌기, 큰 보스는 배 위 호(top_sway.dart)
  }

  double _dist(Foe e) => math.sqrt((e.x - top.shipX) * (e.x - top.shipX) + (e.y - top.shipY) * (e.y - top.shipY));

  double _angle(Foe e) => math.atan2(e.y - top.shipY, e.x - top.shipX);

  /// 배에서 바깥쪽으로. approachRadius 밖으로는 밀지 않는다.
  @override
  void push(Foe e, double distance) {
    if (e.passX != null || e.vanguard) return; // 지나가는 배는 경로를, 돌격대는 돌진을 지킨다
    if (e.boss) e.breakPull += distance.abs(); // 보스 브레이크(boss_break.dart)
    final d = _dist(e);
    if (d == 0) return;
    _spawn.place(e, _angle(e), math.min(d + distance, math.max(d, top.approachRadius)));
  }

  @override
  void pull(Foe e, double x, double y, double amount) {
    if (e.passX != null || e.vanguard) return;
    if (e.boss) e.breakPull += amount.abs();
    final dx = x - e.x;
    final dy = y - e.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d == 0) return;
    final step = math.min(d, amount.abs()) * (amount > 0 ? 1 : -1);
    e
      ..x += dx / d * step
      ..y += dy / d * step;
  }

  @override
  double zoneRadius(AttackDef a) => _aim.circleRadius(a);

  @override
  Point splitAt(Foe parent, int i, int n) {
    final a = i * turn / n;
    return (x: parent.x + math.cos(a) * top.mobRadius, y: parent.y + math.sin(a) * top.mobRadius);
  }

  /// 배를 향한다(원을 도는 보스도 배 쪽을 본다). 스쳐 지나가는 배는 지나가는 방향.
  @override
  double heading(Foe e) {
    final px = e.passX;
    return px != null ? math.atan2(e.passY ?? 0, px) : math.atan2(top.shipY - e.y, top.shipX - e.x);
  }

  @override
  Point get viewShip => ship;

  /// 배 중심에서 조준점 방향으로, 배 둘레(포구)에서 쏜다.
  @override
  ({double x, double y, double angle}) muzzle(double tx, double ty) {
    final a = math.atan2(ty - top.shipY, tx - top.shipX);
    return (x: top.shipX + math.cos(a) * top.shipRadius, y: top.shipY + math.sin(a) * top.shipRadius, angle: a);
  }
}

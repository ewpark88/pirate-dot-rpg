import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show spawnWaveFoes;
import 'package:game_core/src/battle/targeting.dart' show Volley;
import 'package:game_core/src/battle/topdown/geometry.dart';
import 'package:game_core/src/battle/topdown/top_aim.dart';
import 'package:game_core/src/battle/topdown/top_field.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 한 바퀴(라디안).
const double _turn = math.pi / half;

/// 탑다운: 배 중심 고정, 적은 사방에서 무리로 다가오고, 보스는 배 둘레 원을 돈다 (탑다운 전환 T1).
class TopGeometry implements BattleGeometry {
  TopGeometry(this.w, this.top) : _aim = TopAim(top, w);

  /// `waves.json`의 `top` 절로. [shipRadius]가 있으면 배 반경만 그것으로(배 등급별 크기).
  factory TopGeometry.of(WavesTable w, {double? shipRadius, double? hullHalfWidth, double? hullHalfLength}) =>
      TopGeometry(w, TopField.of(w).withShipRadius(shipRadius, halfWidth: hullHalfWidth, halfLength: hullHalfLength));

  final WavesTable w;
  final TopField top;
  final TopAim _aim;

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

  @override
  List<Volley> aimMany(AttackDef a, int n, List<Foe> foes, Rng rng, {double reachBonus = 0}) =>
      _aim.aimMany(a, n, foes, rng, reachBonus: reachBonus);

  /// 배 둘레 → [e] 가장자리.
  double edge(Foe e) => _aim.edge(e);

  /// 배 중심에서 [angle] 방향으로 보이는 테두리까지의 거리.
  double _toBorder(double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    final tx = c > 0 ? (top.width - top.shipX) / c : (c < 0 ? -top.shipX / c : double.infinity);
    final ty = s > 0 ? (top.height - top.shipY) / s : (s < 0 ? -top.shipY / s : double.infinity);
    return math.min(tx, ty);
  }

  void _place(Foe e, double angle, double distance) {
    e
      ..x = top.shipX + math.cos(angle) * distance
      ..y = top.shipY + math.sin(angle) * distance;
  }

  /// 수치·종류는 spawnWaveFoes가 만들고, 여기서 자리를 정한다: 방향 묶음(1~3개)마다 퍼져서
  /// 화면 테두리 바깥과 approachRadius 원 중 먼 곳에서(어느 방향이든 원 안의 걷는 거리가 같게),
  /// 묶음 안 k번째는 k × spawnSpacing만큼 더 바깥(옆모습의 줄 간격과 같은 시간차).
  @override
  void spawnWave(Field f, int stage, SystemContext ctx, {int? count, String? kind}) {
    final before = f.foes.length;
    spawnWaveFoes(f, stage, ctx, count: count, kind: kind);
    final added = f.foes.sublist(before);
    if (added.isEmpty) return;
    final rng = ctx.rng;
    final groups = top.swarmGroupsMin + rng.nextInt(top.swarmGroupsMax - top.swarmGroupsMin + 1);
    final heads = [for (var g = 0; g < groups; g++) _heading(rng)];
    final spread = top.swarmSpreadDeg * radiansPerDegree;
    for (var i = 0; i < added.length; i++) {
      final angle = heads[i % groups] + (rng.nextDouble() - half) * spread;
      final r = top.radiusOf(added[i]);
      final out = math.max(_toBorder(angle) + top.spawnMargin + r, top.approachRadius);
      _place(added[i], angle, out + (i ~/ groups) * top.swarmSpacing);
    }
  }

  /// 묶음 방향 하나: 가중이 있으면 위·오른쪽·아래·왼쪽 사분면(각 90°)을 가중대로 고른 뒤 그 안에서 고르게.
  double _heading(Rng rng) {
    final wt = top.spawnWeights;
    if (wt == null) return rng.nextDouble() * _turn;
    const quarter = _turn * half * half;
    final r = rng.nextDouble() * (wt.up + wt.side + wt.down + wt.side);
    // 사분면 중심: 위 −90°, 오른쪽 0°, 아래 90°, 왼쪽 180°.
    final center = r < wt.up
        ? -quarter
        : r < wt.up + wt.side
        ? 0.0
        : r < wt.up + wt.side + wt.down
        ? quarter
        : quarter / half;
    return center + (rng.nextDouble() - half) * quarter;
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
      _place(boss, up, top.bossSpawnRadius + top.bossRadius);
    }
    final arms = f.foes.where((e) => e.ownerId == boss.id).toList();
    for (var i = 0; i < arms.length; i++) {
      _place(arms[i], up + (i + 1) * _turn / (arms.length + 1), top.bossStandoff);
    }
  }

  /// 배(보스는 standoff 원)까지 다가간다. approachRadius 밖에서는 해류로 빠르게.
  @override
  bool advance(Foe e, double speed, double dt) {
    final dx = e.x - top.shipX;
    final dy = e.y - top.shipY;
    final d = math.sqrt(dx * dx + dy * dy);
    if (e.boss ? d <= top.bossStandoff : _touching(e.x, e.y)) return true;
    final step = speed * dt * (d > top.approachRadius ? top.approachBoost : 1) * (e.boss ? 1 : top.mobSpeedScale);
    // 잡몹은 선체 몸통(캡슐)에 닿는 곳까지, 보스는 standoff 원까지.
    final near = top.hullHalfLength + top.mobRadius; // 이보다 멀면 몸통에 닿을 수 없다(탐색 생략)
    final nd = e.boss
        ? math.max(top.bossStandoff, d - step)
        : (d - step > near ? d - step : math.max(_touchDist(dx / d, dy / d), d - step));
    e
      ..x = top.shipX + dx / d * nd
      ..y = top.shipY + dy / d * nd;
    return false;
  }

  /// 선체 캡슐 몸통에서 점까지(음수 = 몸통 안). 축은 배 중심을 지나는 세로선.
  double hullGap(double x, double y) {
    final reach = math.max(0, top.hullHalfLength - top.hullHalfWidth);
    final cy = (y - top.shipY).clamp(-reach, reach).toDouble();
    final dx = x - top.shipX;
    final dy = y - top.shipY - cy;
    return math.sqrt(dx * dx + dy * dy) - top.hullHalfWidth;
  }

  bool _touching(double x, double y) => hullGap(x, y) <= top.mobRadius;

  /// 배 중심에서 방향 ([ux],[uy])으로 갈 때 잡몹이 몸통에 닿는 거리(이분 탐색).
  double _touchDist(double ux, double uy) {
    var lo = 0.0;
    var hi = top.hullHalfLength + top.hullHalfWidth + top.mobRadius;
    for (var i = 0; i < top.mobRadius.ceil() * top.mobRadius.ceil(); i++) {
      final mid = (lo + hi) * half;
      if (_touching(top.shipX + ux * mid, top.shipY + uy * mid)) {
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
        if (e.alive && !e.boss && e.ownerId == null) e,
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
        _place(e, _angle(e), _touchDist((e.x - top.shipX) / d, (e.y - top.shipY) / d));
      }
    }
    for (final b in f.foes) {
      if (!b.boss || !b.alive || b.stunned || _dist(b) > top.bossStandoff + 1) continue;
      _place(b, _angle(b) + top.bossOrbitDegPerSec * radiansPerDegree * dt, top.bossStandoff);
    }
  }

  double _dist(Foe e) => math.sqrt((e.x - top.shipX) * (e.x - top.shipX) + (e.y - top.shipY) * (e.y - top.shipY));

  double _angle(Foe e) => math.atan2(e.y - top.shipY, e.x - top.shipX);

  /// 배에서 바깥쪽으로. approachRadius 밖으로는 밀지 않는다.
  @override
  void push(Foe e, double distance) {
    final d = _dist(e);
    if (d == 0) return;
    _place(e, _angle(e), math.min(d + distance, math.max(d, top.approachRadius)));
  }

  @override
  void pull(Foe e, double x, double y, double amount) {
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
    final a = i * _turn / n;
    return (x: parent.x + math.cos(a) * top.mobRadius, y: parent.y + math.sin(a) * top.mobRadius);
  }

  /// 배를 향한다(원을 도는 보스도 배 쪽을 본다).
  @override
  double heading(Foe e) => math.atan2(top.shipY - e.y, top.shipX - e.x);

  @override
  Point get viewShip => ship;

  /// 배 중심에서 조준점 방향으로, 배 둘레(포구)에서 쏜다.
  @override
  ({double x, double y, double angle}) muzzle(double tx, double ty) {
    final a = math.atan2(ty - top.shipY, tx - top.shipX);
    return (x: top.shipX + math.cos(a) * top.shipRadius, y: top.shipY + math.sin(a) * top.shipRadius, angle: a);
  }
}

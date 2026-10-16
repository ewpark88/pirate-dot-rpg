import 'dart:math' as math;

import 'package:game_core/src/battle/beam.dart';
import 'package:game_core/src/battle/cluster.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/legend.dart';
import 'package:game_core/src/battle/sortie.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

/// 날아가는 선원 탄 (선원 개성 v2 3절). [arriveTick]에 조준점(volley.x·y)에 떨어진다.
class Flight {
  Flight({
    required this.gun,
    required this.attack,
    required this.volley,
    required this.base,
    required this.crit,
    required this.arriveTick,
  });

  final Gun gun;
  final AttackDef attack;

  /// 쏠 때의 조준(조준점 = 떨어질 자리, 맞을 적 목록·비율).
  final Volley volley;
  final BigNum base;
  final bool crit;
  final int arriveTick;
}

/// 선원 탄 비행: 쏘기(예측 사격 포함)와 도착 판정.
extension Flights on Round {
  /// [v]를 쏜다: 탄이 있는 공격이면 비행을 띄우고 비행 틱을 돌려준다(도착 때 판정). 즉시형이면 null(호출자가 바로 맞힌다).
  ({Volley volley, int ticks})? launch(Gun g, AttackDef a, Volley v, BigNum base, {required bool crit}) {
    final sortie = launchSortie(g, a, v, base, crit: crit); // 강습·공중: 선원 본인이 출격(sortie.dart)
    if (sortie != null) return sortie;
    final beam = launchBeam(g, a, v, base, crit: crit); // 레이저: 빔 유지(beam.dart)
    if (beam != null) return beam;
    final p = a.projectile;
    final geo = this.geo;
    if (p == null || (p.speed <= 0 && p.delaySec <= 0) || geo is! TopGeometry) return null;
    final from = geo.muzzle(v.x, v.y);
    int ticksTo(double x, double y) => math.max(1, (_len(x - from.x, y - from.y) / p.speed / dt).round());
    var aimed = v;
    if (p.delaySec > 0) {
      // 낙뢰: 예고 delaySec 뒤 쏠 때의 자리에 떨어진다(대상이 움직이면 빗나갈 수 있다).
      final ticks = math.max(1, (p.delaySec / dt).round());
      field.flights.add(Flight(gun: g, attack: a, volley: v, base: base, crit: crit, arriveTick: ctx.tick + ticks));
      return (volley: v, ticks: ticks);
    }
    var ticks = ticksTo(v.x, v.y);
    final target = v.hits.isEmpty ? null : v.hits.first.foe;
    if (p.lead && target != null && a.shape != 'push') {
      // 예측: 탄이 닿는 시각 τ = |대상(τ) − 포구| ÷ 탄속을 이분 탐색(틱 단위까지). 대상이 탄보다 빨라 못 따라잡으면 마지막 자리.
      double gap(double sec) {
        final at = _predict(geo, target, sec);
        return _len(at.x - from.x, at.y - from.y) - p.speed * sec;
      }

      var lo = 0.0;
      var hi = ticks * dt;
      final most = geo.top.viewHeight / p.speed; // 화면 세로를 나는 시간보다 길게는 보지 않는다
      while (gap(hi) > 0 && hi < most) {
        hi += hi; // 늘려 잡기(대상이 멀어지는 경우)
      }
      while (hi - lo > dt) {
        final mid = (lo + hi) * half;
        if (gap(mid) > 0) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      final at = _predict(geo, target, hi);
      aimed = (x: at.x, y: at.y, hits: v.hits);
      ticks = ticksTo(at.x, at.y);
    }
    field.flights.add(Flight(gun: g, attack: a, volley: aimed, base: base, crit: crit, arriveTick: ctx.tick + ticks));
    return (volley: aimed, ticks: ticks);
  }

  /// 도착한 탄: 범위(circle)는 떨어진 자리 반경 안 적 전부, 그 밖은 떨어진 자리 hitRadius 안 가장 가까운 적
  /// (조준한 적이면 쏠 때의 연쇄·관통 목록 그대로). 아무도 없으면 AttackMissed.
  void tickFlights() {
    final geo = this.geo;
    if (field.flights.isEmpty || geo is! TopGeometry) return;
    final due = field.flights.where((f) => f.arriveTick <= ctx.tick).toList();
    if (due.isEmpty) return;
    field.flights.removeWhere(due.contains);
    for (final f in due) {
      if (isBomblet(f.attack)) {
        final radius = geo.zoneRadius(f.attack);
        ctx.emit(BombletBurst(ctx.tick, crewId: f.gun.crewId, x: f.volley.x, y: f.volley.y, radius: radius));
      }
      final v = _landing(geo, f);
      if (v == null) {
        // 원형 탄막의 빈 탄(처음부터 노린 적 없음)은 MISS를 띄우지 않는다
        if (f.volley.hits.isNotEmpty) {
          ctx.emit(AttackMissed(ctx.tick, crewId: f.gun.crewId, x: f.volley.x, y: f.volley.y));
        }
        continue;
      }
      land(f.gun, f.attack, v, f.base, crit: f.crit);
      if (!isBomblet(f.attack)) legendAfterHit(this, f.gun, v, f.base, crit: f.crit);
    }
  }

  Volley? _landing(TopGeometry geo, Flight f) {
    final a = f.attack;
    final x = f.volley.x;
    final y = f.volley.y;
    double dist(Foe e) => _len(e.x - x, e.y - y);
    final pool = [
      for (final e in field.foes)
        if (e.alive && e.holdSec <= 0 && e.eventKind != 'goldfish' && !a.excludeLayers.contains(e.layer)) e,
    ];
    if (a.shape == 'circle') {
      final radius = geo.zoneRadius(a); // 원 반지름(topRadius)
      final hit = pool.where((e) => dist(e) <= radius + geo.top.radiusOf(e)).toList()
        ..sort((p, q) => dist(p).compareTo(dist(q)));
      return hit.isEmpty ? null : (x: x, y: y, hits: spread(hit, w));
    }
    final reach = a.projectile!.hitRadius;
    final near = pool.where((e) => dist(e) <= reach + geo.top.radiusOf(e)).toList()
      ..sort((p, q) => dist(p).compareTo(dist(q)));
    if (near.isEmpty) return null;
    final aimed = f.volley.hits.isEmpty ? null : f.volley.hits.first.foe; // 원형 탄막의 빈 탄은 조준한 적이 없다
    if (aimed != null && near.contains(aimed)) {
      return (
        x: x,
        y: y,
        hits: [
          for (final h in f.volley.hits)
            if (h.foe.alive) h,
        ],
      );
    }
    return (x: x, y: y, hits: [(foe: near.first, factor: 1.0)]);
  }

  /// [e]가 [sec]초 뒤 있을 자리(배를 향해 곧게 — 몸통·standoff 앞에서 멈춤, 스쳐 가는 적은 그 방향으로).
  ({double x, double y}) _predict(TopGeometry geo, Foe e, double sec) {
    if (e.holdSec > 0 || e.stunned) return (x: e.x, y: e.y);
    final speed = e.speed * geo.speedScale * (e.standsOff ? 1 : geo.top.mobSpeedScale);
    final px = e.passX;
    if (px != null) return (x: e.x + px * speed * sec, y: e.y + (e.passY ?? 0) * speed * sec);
    final dx = geo.top.shipX - e.x;
    final dy = geo.top.shipY - e.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d <= 0) return (x: e.x, y: e.y);
    final room = e.standsOff
        ? math.max(0, d - geo.top.bossStandoff)
        : math.max(0, geo.hullGap(e.x, e.y) - geo.top.radiusOf(e));
    final step = math.min(speed * sec, room.toDouble());
    return (x: e.x + dx / d * step, y: e.y + dy / d * step);
  }
}

double _len(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/targeting.dart' show Hit, Volley, attackReach, spread;
import 'package:game_core/src/battle/topdown/top_field.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 탑다운 조준: 계열 8종의 2D 모양 (docs/contracts/requests/platform-topdown-t0.md D).
/// 거리는 배 둘레 → 적 가장자리(skills.json reach를 배에서 반경으로).
class TopAim {
  TopAim(this.top, this.w) : viewX = top.shipX, viewY = top.shipY;

  /// 지금 배 자리(피버 좌우 이동 때 TopGeometry.weave가 바꾼다).
  TopField top;

  /// 카메라 가운데 x — 배가 좌우로 움직여도 카메라(보이는 사각형)는 바다 가운데 그대로.
  final double viewX;
  final double viewY;

  /// 먹물 구름(도감 v2): 이 원들 안의 적은 조준되지 않는다. 보스 패턴이 매 틱 정한다.
  List<({double x, double y, double r, int until})> blinds = const [];
  final WavesTable w;

  double _centerDist(Foe e) => _dist(e.x, e.y, top.shipX, top.shipY);

  // 탑다운 모양 키(skills.json attack, 선택): 없으면 옆모습 값 그대로. T4-B(S3 제안) — 줄 서는 무리가 없는 탑다운에 맞춘 모양.
  /// 원(투척·수중 장판) 반지름 / 충격 고리 범위: `topRadius`.
  double circleRadius(AttackDef a) => a.raw.numberOr('topRadius', a.radius);
  double ringRange(AttackDef a) => a.raw.numberOr('topRadius', a.range);

  /// 관통 광선의 반폭: `topWidth`(없으면 width의 절반).
  double beamHalfWidth(AttackDef a) => a.raw.has('topWidth') ? a.raw.number('topWidth') : a.width * half;

  /// 강습 부채꼴 길이(배 몸통에서): `topRange`.
  double coneRange(AttackDef a) => a.raw.numberOr('topRange', a.range);

  /// 강습 부채꼴 각(도): `topArcDeg`.
  double arcDeg(AttackDef a) => a.raw.numberOr('topArcDeg', a.angleDeg);

  /// 배 둘레에서 [e] 가장자리까지.
  double edge(Foe e) {
    // 선체 캡슐 몸통에서(없으면 반경 shipRadius 원 — 캡슐 반폭·반길이가 모두 shipRadius).
    final reach = math.max(0, top.hullHalfLength - top.hullHalfWidth);
    final hy = top.shipY + top.hullOffset;
    final cy = (e.y - hy).clamp(-reach, reach).toDouble();
    return _dist(e.x, e.y, top.shipX, hy + cy) - top.hullHalfWidth - top.radiusOf(e);
  }

  /// 카메라 안이고 등장 대기 중이 아닌가(대기·가까이 등장 예고 중엔 조준·궁극기 대상이 아니다).
  bool onScreen(Foe e) =>
      e.holdSec <= 0 && (e.x - viewX).abs() <= top.viewWidth * half && (e.y - viewY).abs() <= top.viewHeight * half;

  List<Foe> eligible(AttackDef a, List<Foe> foes, {double reachBonus = 0}) {
    final r = attackReach(a, w.field);
    final reach = r == null ? null : r * top.reachScale + reachBonus;
    return [
      for (final e in foes)
        // 황금 물고기(돌발 이벤트)는 탭으로만 잡는다 — 자동 조준에서 뺀다(S2 스펙).
        if (e.alive &&
            e.eventKind != 'goldfish' &&
            !blinds.any((b) => (e.x - b.x) * (e.x - b.x) + (e.y - b.y) * (e.y - b.y) <= b.r * b.r) &&
            onScreen(e) &&
            !a.excludeLayers.contains(e.layer) &&
            (reach == null || edge(e) <= reach))
          e,
    ];
  }

  List<Volley> aimMany(AttackDef a, int n, List<Foe> foes, Rng rng, {double reachBonus = 0}) {
    if (a.shape == 'ring') return ring(a, n, foes, reachBonus: reachBonus);
    final out = <Volley>[];
    final avoid = <Foe>{};
    for (var i = 0; i < n; i++) {
      final v = aim(a, foes, rng, avoid: avoid, reachBonus: reachBonus);
      if (v == null) break;
      out.add(v);
      avoid.addAll(a.shape == 'circle' ? v.hits.map((h) => h.foe) : [v.hits.first.foe]);
    }
    return out;
  }

  /// 한 발. 맞힐 적이 없으면 null. [avoid]는 조준(중심·첫 대상)으로 고르지 않는다.
  Volley? aim(AttackDef a, List<Foe> foes, Rng rng, {Set<Foe> avoid = const {}, double reachBonus = 0}) {
    final targets = eligible(a, foes, reachBonus: reachBonus);
    final pickable = targets.where((e) => !avoid.contains(e)).toList();
    if (pickable.isEmpty) return null;
    Foe first() => pickFirst(a, pickable, rng);

    final List<Foe> hit;
    var falloff = false;
    double ax;
    double ay;
    switch (a.shape) {
      case 'circle' || 'cluster': // 집속탄 본탄도 무리 중심에(자탄은 cluster.dart)
        final radius = circleRadius(a);
        int around(Foe c) => targets.where((e) => _dist(e.x, e.y, c.x, c.y) <= radius).length;
        // 무리 중심(계열 기본 cluster) — 선원 개성 v2가 다른 조준(가장 강한·무작위 등)을 주면 그 적을 중심으로.
        final center = a.targets != null && a.targets != 'cluster'
            ? first()
            : pickable.reduce((m, e) {
                final d = around(e) - around(m);
                return d > 0 || (d == 0 && _centerDist(e) < _centerDist(m)) ? e : m;
              });
        (ax, ay) = (center.x, center.y);
        hit = targets.where((e) => _dist(e.x, e.y, ax, ay) <= radius).toList()
          ..sort((p, q) => _dist(p.x, p.y, ax, ay).compareTo(_dist(q.x, q.y, ax, ay)));
      case 'line' || 'laser': // 레이저(계열 v3)도 같은 광선 — 관통 수는 laserPierce(0 = 화면 끝까지), 감쇠 없음
        // 배 → 대상 방향 광선(폭 안, 배 앞쪽만, 가까운 순 pierce마리). 대상은 그 광선에 가장 많이 걸리는 적
        // (같으면 가까운 쪽) — 옆모습에서 한 줄(레인)로 오는 무리를 꿰뚫던 것과 같은 몫.
        List<Foe> along(Foe t) {
          final len = _centerDist(t);
          final ux = len == 0 ? 1.0 : (t.x - top.shipX) / len;
          final uy = len == 0 ? 0.0 : (t.y - top.shipY) / len;
          double proj(Foe e) => (e.x - top.shipX) * ux + (e.y - top.shipY) * uy;
          double off(Foe e) => ((e.x - top.shipX) * uy - (e.y - top.shipY) * ux).abs();
          return (targets.where((e) => proj(e) > 0 && off(e) <= beamHalfWidth(a)).toList()
                ..sort((p, q) => proj(p).compareTo(proj(q))))
              .take(pierceOf(a, targets.length))
              .toList();
        }
        var best = first();
        var bestHit = along(best);
        for (final c in pickable) {
          final h = along(c);
          if (h.length > bestHit.length || (h.length == bestHit.length && _centerDist(c) < _centerDist(best))) {
            best = c;
            bestHit = h;
          }
        }
        (ax, ay) = (best.x, best.y);
        hit = bestHit;
        falloff = a.shape == 'line';
      case 'chain':
        final start = first();
        (ax, ay) = (start.x, start.y);
        hit = [start];
        final limit = math.min(a.chains, w.chainMax);
        while (hit.length < limit) {
          final rest = targets.where((e) => !hit.contains(e));
          if (rest.isEmpty) break;
          hit.add(nearest(rest, hit.last.x, hit.last.y));
        }
        falloff = true;
      case 'random':
        final air = pickable.where((e) => e.layer == 'air').toList();
        final pool = air.isNotEmpty ? air : List.of(pickable);
        hit = [];
        while (hit.length < a.count && pool.isNotEmpty) {
          hit.add(pool.removeAt(rng.nextInt(pool.length)));
        }
        (ax, ay) = (hit.first.x, hit.first.y);
      case 'cone':
        // 가장 가까운 적 방향 부채꼴. 배 둘레에서 range 안(보스는 사거리 안이면 됨), coneNearPx 안은 각도와 상관없이.
        final t = first();
        final dir = math.atan2(t.y - top.shipY, t.x - top.shipX);
        final halfAngle = arcDeg(a) * half * radiansPerDegree;
        hit = [
          for (final e in targets)
            if ((e.standsOff || edge(e) <= coneRange(a)) &&
                (edge(e) <= w.field.coneNearPx ||
                    _angleBetween(math.atan2(e.y - top.shipY, e.x - top.shipX), dir) <= halfAngle))
              e,
        ]..sort((p, q) => edge(p).compareTo(edge(q)));
        if (hit.isEmpty) return null;
        (ax, ay) = (hit.first.x, hit.first.y);
      case 'push':
        // 배 둘레 고리: 둘레에서 range 안 전부. 보스는 사거리 안이면 range와 상관없이(옆모습과 같은 규칙 — 보스는 멀리 선다).
        hit = targets.where((e) => e.standsOff || edge(e) <= ringRange(a)).toList()
          ..sort((p, q) => edge(p).compareTo(edge(q)));
        if (hit.isEmpty) return null;
        (ax, ay) = (top.shipX, top.shipY);
      default: // single
        final t = first();
        (ax, ay) = (t.x, t.y);
        hit = [t];
    }
    return (x: ax, y: ay, hits: spread(hit, w, falloff: falloff));
  }

  /// 원형 탄막(계열 v3): 배를 중심으로 [n]방향 고르게(가장 가까운 적 쪽부터). 방향마다 광선 위 첫 적(사거리 안),
  /// 없으면 사거리 끝으로 빈 탄(맞을 적 없음 — 연출만). 보이는 적이 하나도 없으면 쏘지 않는다.
  List<Volley> ring(AttackDef a, int n, List<Foe> foes, {double reachBonus = 0}) {
    final targets = eligible(a, foes, reachBonus: reachBonus);
    if (targets.isEmpty) return const [];
    final near = nearest(targets, top.shipX, top.shipY);
    final r = attackReach(a, w.field);
    final reach = (r == null ? top.viewHeight * half : r * top.reachScale + reachBonus) + top.shipRadius;
    final start = math.atan2(near.y - top.shipY, near.x - top.shipX);
    return [
      for (var i = 0; i < n; i++)
        () {
          final angle = start + math.pi / half * i / n;
          final ux = math.cos(angle);
          final uy = math.sin(angle);
          double proj(Foe e) => (e.x - top.shipX) * ux + (e.y - top.shipY) * uy;
          double off(Foe e) => ((e.x - top.shipX) * uy - (e.y - top.shipY) * ux).abs();
          final on = targets.where((e) => proj(e) > 0 && off(e) <= beamHalfWidth(a) + top.radiusOf(e)).toList()
            ..sort((p, q) => proj(p).compareTo(proj(q)));
          if (on.isNotEmpty) return (x: on.first.x, y: on.first.y, hits: [(foe: on.first, factor: 1.0)]);
          return (x: top.shipX + ux * reach, y: top.shipY + uy * reach, hits: <Hit>[]);
        }(),
    ];
  }

  /// 광선이 꿰는 수: 레이저는 laserPierce(0 = 전부 — [all]), 그 밖은 pierce.
  int pierceOf(AttackDef a, int all) {
    if (a.shape != 'laser') return a.pierce;
    final n = a.raw.numberOr('laserPierce', 1).round();
    return n <= 0 ? all : n;
  }

  /// 지금 배에서 (ux, uy) 방향 광선 위 적(가까운 순, 관통 수만큼) — 레이저 빔이 매 틱 다시 잰다.
  List<Foe> beamHits(AttackDef a, double ux, double uy, List<Foe> foes) {
    final targets = eligible(a, foes);
    double proj(Foe e) => (e.x - top.shipX) * ux + (e.y - top.shipY) * uy;
    double off(Foe e) => ((e.x - top.shipX) * uy - (e.y - top.shipY) * ux).abs();
    return (targets.where((e) => proj(e) > 0 && off(e) <= beamHalfWidth(a)).toList()
          ..sort((p, q) => proj(p).compareTo(proj(q))))
        .take(pierceOf(a, targets.length))
        .toList();
  }

  /// 첫 대상(선원 개성 v2 조준 8종, docs/specs/platform-crew-identity-v2.md 1절). 계열 기본값 nearest·front는 가까운 적.
  Foe pickFirst(AttackDef a, List<Foe> pool, Rng rng) {
    Foe most(double Function(Foe) score) => pool.reduce((m, e) => score(e) > score(m) ? e : m);
    final close = nearest(pool, top.shipX, top.shipY);
    switch (a.targets) {
      case 'strongest':
        return pool.reduce((m, e) => e.hp > m.hp ? e : m);
      case 'weakest':
        return pool.reduce((m, e) => e.hp < m.hp ? e : m);
      case 'boss':
        return pool.where((e) => e.boss).firstOrNull ?? pool.reduce((m, e) => e.hp > m.hp ? e : m);
      case 'farthest':
        return most(edge);
      case 'air':
        final air = pool.where((e) => e.layer == 'air');
        return air.isEmpty ? close : nearest(air, top.shipX, top.shipY);
      case 'random':
        return pool[rng.nextInt(pool.length)];
      case 'cluster':
        // 둘레(적 지름 cluster 반경 — aim `clusterRadius`, 없으면 잡몹 지름) 안 이웃이 가장 많은 적, 같으면 가까운 쪽.
        final r = a.raw.numberOr('clusterRadius', top.mobRadius / half);
        int around(Foe c) => pool.where((e) => _dist(e.x, e.y, c.x, c.y) <= r).length;
        return pool.reduce((m, e) {
          final d = around(e) - around(m);
          return d > 0 || (d == 0 && _centerDist(e) < _centerDist(m)) ? e : m;
        });
      default:
        return close;
    }
  }
}

Foe nearest(Iterable<Foe> pool, double x, double y) =>
    pool.reduce((m, e) => _dist(e.x, e.y, x, y) < _dist(m.x, m.y, x, y) ? e : m);

/// 두 각의 차(0~π).
double _angleBetween(double a, double b) {
  final d = (a - b).abs() % (math.pi / half);
  return d > math.pi ? math.pi / half - d : d;
}

double _dist(double x1, double y1, double x2, double y2) {
  final dx = x1 - x2;
  final dy = y1 - y2;
  return math.sqrt(dx * dx + dy * dy);
}

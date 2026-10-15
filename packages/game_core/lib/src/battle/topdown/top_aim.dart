import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/targeting.dart' show Volley, attackReach, spread;
import 'package:game_core/src/battle/topdown/top_field.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 탑다운 조준: 계열 8종의 2D 모양 (docs/contracts/requests/platform-topdown-t0.md D).
/// 거리는 배 둘레 → 적 가장자리(skills.json reach를 배에서 반경으로).
class TopAim {
  TopAim(this.top, this.w);

  final TopField top;
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

  bool onScreen(Foe e) =>
      (e.x - top.shipX).abs() <= top.viewWidth * half && (e.y - top.shipY).abs() <= top.viewHeight * half;

  List<Foe> eligible(AttackDef a, List<Foe> foes, {double reachBonus = 0}) {
    final r = attackReach(a, w.field);
    final reach = r == null ? null : r * top.reachScale + reachBonus;
    return [
      for (final e in foes)
        if (e.alive && onScreen(e) && !a.excludeLayers.contains(e.layer) && (reach == null || edge(e) <= reach)) e,
    ];
  }

  List<Volley> aimMany(AttackDef a, int n, List<Foe> foes, Rng rng, {double reachBonus = 0}) {
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
    Foe nearest(Iterable<Foe> pool, double x, double y) =>
        pool.reduce((m, e) => _dist(e.x, e.y, x, y) < _dist(m.x, m.y, x, y) ? e : m);
    Foe first() => a.targets == 'strongest'
        ? pickable.reduce((m, e) => e.hp > m.hp ? e : m)
        : nearest(pickable, top.shipX, top.shipY);

    final List<Foe> hit;
    var falloff = false;
    double ax;
    double ay;
    switch (a.shape) {
      case 'circle':
        final radius = circleRadius(a);
        int around(Foe c) => targets.where((e) => _dist(e.x, e.y, c.x, c.y) <= radius).length;
        final center = pickable.reduce((m, e) {
          final d = around(e) - around(m);
          return d > 0 || (d == 0 && _centerDist(e) < _centerDist(m)) ? e : m;
        });
        (ax, ay) = (center.x, center.y);
        hit = targets.where((e) => _dist(e.x, e.y, ax, ay) <= radius).toList()
          ..sort((p, q) => _dist(p.x, p.y, ax, ay).compareTo(_dist(q.x, q.y, ax, ay)));
      case 'line':
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
              .take(a.pierce)
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
        falloff = true;
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
            if ((e.boss || edge(e) <= coneRange(a)) &&
                (edge(e) <= w.field.coneNearPx ||
                    _angleBetween(math.atan2(e.y - top.shipY, e.x - top.shipX), dir) <= halfAngle))
              e,
        ]..sort((p, q) => edge(p).compareTo(edge(q)));
        if (hit.isEmpty) return null;
        (ax, ay) = (hit.first.x, hit.first.y);
      case 'push':
        // 배 둘레 고리: 둘레에서 range 안 전부. 보스는 사거리 안이면 range와 상관없이(옆모습과 같은 규칙 — 보스는 멀리 선다).
        hit = targets.where((e) => e.boss || edge(e) <= ringRange(a)).toList()
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
}

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

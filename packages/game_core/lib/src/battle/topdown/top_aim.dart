import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/targeting.dart' show Volley, attackReach, spread;
import 'package:game_core/src/battle/topdown/top_field.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 탑다운 조준: 계열 8종의 2D 모양 (docs/contracts/requests/platform-topdown-t0.md D).
/// 거리는 배 둘레 → 적 가장자리. 옆모습(targeting.dart)과 같은 규칙을 '배에서 x 거리' 대신 '배에서 반경'으로.
class TopAim {
  TopAim(this.top, this.w);

  final TopField top;
  final WavesTable w;

  double _centerDist(Foe e) => _dist(e.x, e.y, top.shipX, top.shipY);

  /// 배 둘레에서 [e] 가장자리까지.
  double edge(Foe e) => _centerDist(e) - top.shipRadius - top.radiusOf(e);

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
        int around(Foe c) => targets.where((e) => _dist(e.x, e.y, c.x, c.y) <= a.radius).length;
        final center = pickable.reduce((m, e) {
          final d = around(e) - around(m);
          return d > 0 || (d == 0 && _centerDist(e) < _centerDist(m)) ? e : m;
        });
        (ax, ay) = (center.x, center.y);
        hit = targets.where((e) => _dist(e.x, e.y, ax, ay) <= a.radius).toList()
          ..sort((p, q) => _dist(p.x, p.y, ax, ay).compareTo(_dist(q.x, q.y, ax, ay)));
      case 'line':
        // 배 → 첫 대상 방향 광선. 폭 안, 배 앞쪽(투영 > 0)만, 가까운 순 pierce마리.
        final t = first();
        (ax, ay) = (t.x, t.y);
        final len = _centerDist(t);
        final ux = len == 0 ? 1.0 : (t.x - top.shipX) / len;
        final uy = len == 0 ? 0.0 : (t.y - top.shipY) / len;
        double along(Foe e) => (e.x - top.shipX) * ux + (e.y - top.shipY) * uy;
        double across(Foe e) => ((e.x - top.shipX) * uy - (e.y - top.shipY) * ux).abs();
        hit =
            (targets.where((e) => along(e) > 0 && across(e) <= a.width * half).toList()
                  ..sort((p, q) => along(p).compareTo(along(q))))
                .take(a.pierce)
                .toList();
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
        // 가장 가까운 적 방향 부채꼴. 배 둘레에서 range 안, coneNearPx 안은 각도와 상관없이.
        final t = first();
        final dir = math.atan2(t.y - top.shipY, t.x - top.shipX);
        final halfAngle = a.angleDeg * half * radiansPerDegree;
        hit = [
          for (final e in targets)
            if (edge(e) <= a.range &&
                (edge(e) <= w.field.coneNearPx ||
                    _angleBetween(math.atan2(e.y - top.shipY, e.x - top.shipX), dir) <= halfAngle))
              e,
        ]..sort((p, q) => edge(p).compareTo(edge(q)));
        if (hit.isEmpty) return null;
        (ax, ay) = (hit.first.x, hit.first.y);
      case 'push':
        // 배 둘레 고리: 둘레에서 range 안 전부.
        hit = targets.where((e) => edge(e) <= a.range).toList()..sort((p, q) => edge(p).compareTo(edge(q)));
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

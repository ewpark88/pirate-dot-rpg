import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 맞은 적 하나와 그 적이 받는 피해 비율(연쇄·관통 감쇠, 범위 초과 50% 반영).
typedef Hit = ({Foe foe, double factor});

/// 공격 한 번의 결과. `x`,`y`는 조준점(렌더가 발사체를 날리는 곳).
typedef Volley = ({double x, double y, List<Hit> hits});

/// 계열 기본 공격 모양 8종 (docs/specs/battle-m1-core.md 규칙 5). 맞힐 적이 없으면 null.
Volley? aim(AttackDef a, List<Foe> foes, WavesTable w, Rng rng) {
  final f = w.field;
  final targets = [
    for (final e in foes)
      if (e.alive && e.x <= f.width && !a.excludeLayers.contains(e.layer)) e,
  ];
  if (targets.isEmpty) return null;
  double fromShip(Foe e) => _dist(e.x, e.y, f.shipX, f.shipY);
  Foe nearest(Iterable<Foe> pool, double x, double y) =>
      pool.reduce((m, e) => _dist(e.x, e.y, x, y) < _dist(m.x, m.y, x, y) ? e : m);

  final List<Foe> hit;
  var falloff = false;
  double ax;
  double ay;
  switch (a.shape) {
    case 'circle':
      // 적이 가장 많이 모인 적을 중심으로. 같으면 배에 가까운 쪽.
      int around(Foe c) => targets.where((e) => _dist(e.x, e.y, c.x, c.y) <= a.radius).length;
      final center = targets.reduce((m, e) {
        final d = around(e) - around(m);
        return d > 0 || (d == 0 && fromShip(e) < fromShip(m)) ? e : m;
      });
      ax = center.x;
      ay = center.y;
      hit = targets.where((e) => _dist(e.x, e.y, ax, ay) <= a.radius).toList()
        ..sort((p, q) => _dist(p.x, p.y, ax, ay).compareTo(_dist(q.x, q.y, ax, ay)));
    case 'line':
      final t = nearest(targets, f.shipX, f.shipY);
      (ax, ay) = (t.x, t.y);
      hit = (targets.where((e) => (e.y - t.y).abs() <= a.width * half).toList()..sort((p, q) => p.x.compareTo(q.x)))
          .take(a.pierce)
          .toList();
      falloff = true;
    case 'chain':
      final first = nearest(targets, f.shipX, f.shipY);
      (ax, ay) = (first.x, first.y);
      hit = [first];
      final limit = math.min(a.chains, w.chainMax);
      while (hit.length < limit) {
        final rest = targets.where((e) => !hit.contains(e));
        if (rest.isEmpty) break;
        hit.add(nearest(rest, hit.last.x, hit.last.y));
      }
      falloff = true;
    case 'random':
      // 공중 적 우선, 없으면 전체에서.
      final air = targets.where((e) => e.layer == 'air').toList();
      final pool = air.isNotEmpty ? air : List.of(targets);
      hit = [];
      while (hit.length < a.count && pool.isNotEmpty) {
        hit.add(pool.removeAt(rng.nextInt(pool.length)));
      }
      (ax, ay) = (hit.first.x, hit.first.y);
    case 'cone':
      final halfAngle = a.angleDeg * half * radiansPerDegree;
      hit = [
        for (final e in targets)
          if (e.x - f.shipX <= a.range && math.atan2((e.y - f.shipY).abs(), math.max(e.x - f.shipX, 0)) <= halfAngle) e,
      ]..sort((p, q) => fromShip(p).compareTo(fromShip(q)));
      if (hit.isEmpty) return null;
      (ax, ay) = (hit.first.x, hit.first.y);
    case 'push':
      hit = targets.where((e) => e.x - f.shipX <= a.range).toList()..sort((p, q) => p.x.compareTo(q.x));
      if (hit.isEmpty) return null;
      (ax, ay) = (f.shipX, f.shipY);
    default: // single
      final t = nearest(targets, f.shipX, f.shipY);
      (ax, ay) = (t.x, t.y);
      hit = [t];
  }
  return (x: ax, y: ay, hits: spread(hit, w, falloff: falloff));
}

/// 맞은 순서대로 피해 비율을 붙인다: 연쇄·관통은 한 번마다 `chainFalloff` 감소,
/// `aoe.fullDamageTargets`를 넘은 적은 `aoe.overflowDamage` (설계서 4.8).
List<Hit> spread(List<Foe> hit, WavesTable w, {bool falloff = false}) => [
  for (var i = 0; i < hit.length; i++)
    (
      foe: hit[i],
      factor:
          (falloff ? math.pow(1 - w.chainFalloff, i).toDouble() : 1.0) *
          (i >= w.aoeFullDamageTargets ? w.aoeOverflowDamage : 1.0),
    ),
];

double _dist(double x1, double y1, double x2, double y2) {
  final dx = x1 - x2;
  final dy = y1 - y2;
  return math.sqrt(dx * dx + dy * dy);
}

import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 맞은 적 하나와 그 적이 받는 피해 비율(연쇄·관통 감쇠, 범위 초과 50% 반영).
typedef Hit = ({Foe foe, double factor});

/// 공격 한 번의 결과. `x`,`y`는 조준점(렌더가 발사체를 날리는 곳).
typedef Volley = ({double x, double y, List<Hit> hits});

/// 화면 안에서 [a]가 맞힐 수 있는 적.
List<Foe> eligible(AttackDef a, List<Foe> foes, FieldDef f) => [
  for (final e in foes)
    if (e.alive && e.x <= f.width && !a.excludeLayers.contains(e.layer)) e,
];

/// [n]발을 서로 다른 대상(원형은 서로 다른 중심)에 쏜다 (사다리 `projectiles`, 스킬 `count`).
/// 맞힐 적이 그보다 적으면 있는 만큼만.
List<Volley> aimMany(AttackDef a, int n, List<Foe> foes, WavesTable w, Rng rng) {
  final out = <Volley>[];
  final avoid = <Foe>{};
  for (var i = 0; i < n; i++) {
    final v = aim(a, foes, w, rng, avoid: avoid);
    if (v == null) break;
    out.add(v);
    avoid.addAll(a.shape == 'circle' ? v.hits.map((h) => h.foe) : [v.hits.first.foe]);
  }
  return out;
}

/// 모양 8종 (docs/specs/battle-m1-core.md 규칙 5, battle-m3-skills.md 1). 맞힐 적이 없으면 null.
/// [avoid]는 조준(중심·첫 대상)으로 고르지 않는다 — 여러 발이 서로 다른 곳에 떨어지게.
Volley? aim(AttackDef a, List<Foe> foes, WavesTable w, Rng rng, {Set<Foe> avoid = const {}}) {
  final f = w.field;
  final targets = eligible(a, foes, f);
  final pickable = targets.where((e) => !avoid.contains(e)).toList();
  if (pickable.isEmpty) return null;
  double fromShip(Foe e) => _dist(e.x, e.y, f.shipX, f.shipY);
  Foe nearest(Iterable<Foe> pool, double x, double y) =>
      pool.reduce((m, e) => _dist(e.x, e.y, x, y) < _dist(m.x, m.y, x, y) ? e : m);
  Foe first() =>
      a.targets == 'strongest' ? pickable.reduce((m, e) => e.hp > m.hp ? e : m) : nearest(pickable, f.shipX, f.shipY);

  final List<Foe> hit;
  var falloff = false;
  double ax;
  double ay;
  switch (a.shape) {
    case 'circle':
      // 적이 가장 많이 모인 적을 중심으로. 같으면 배에 가까운 쪽.
      int around(Foe c) => targets.where((e) => _dist(e.x, e.y, c.x, c.y) <= a.radius).length;
      final center = pickable.reduce((m, e) {
        final d = around(e) - around(m);
        return d > 0 || (d == 0 && fromShip(e) < fromShip(m)) ? e : m;
      });
      ax = center.x;
      ay = center.y;
      hit = targets.where((e) => _dist(e.x, e.y, ax, ay) <= a.radius).toList()
        ..sort((p, q) => _dist(p.x, p.y, ax, ay).compareTo(_dist(q.x, q.y, ax, ay)));
    case 'line':
      final t = first();
      (ax, ay) = (t.x, t.y);
      hit = (targets.where((e) => (e.y - t.y).abs() <= a.width * half).toList()..sort((p, q) => p.x.compareTo(q.x)))
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
      // 공중 적 우선, 없으면 전체에서.
      final air = pickable.where((e) => e.layer == 'air').toList();
      final pool = air.isNotEmpty ? air : List.of(pickable);
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
      final t = first();
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

import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/battle/topdown/geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

// 선원 정리 2안(docs/balance/BALANCE.md 4절, S1 승인 2026-10-17): '탄 +n'이 8명에게 겹쳐 개성이 흐려져
// sword·saw·bara·lobster·davy를 각자 다른 능력으로 바꾼다. 값은 skills.json legends(LegendDef), 난수를 쓰지 않는다(결정론).

/// 발사 때 한 발의 맞을 적·비율을 바꾼다: 관통 가속(sword) · 휩쓸기(lobster).
Volley reshapeVolley(Gun g, Volley v, List<Foe> foes, WavesTable w, BattleGeometry geo) {
  final l = g.legend;
  if (l == null || v.hits.isEmpty) return v;
  var out = v;
  if (l.sweep case final s?) out = _sweep(g, out, foes, geo, s);
  if (l.pierceRamp > 0 && out.hits.length > 1) {
    // 감쇠 대신 꿰뚫을 때마다 × (1 + pierceRamp) — 무리를 길게 꿰뚫을수록 세진다.
    final base = spread([for (final h in out.hits) h.foe], w);
    out = (
      x: out.x,
      y: out.y,
      hits: [
        for (final (i, h) in base.indexed) (foe: h.foe, factor: h.factor * math.pow(1 + l.pierceRamp, i).toDouble()),
      ],
    );
  }
  return out;
}

/// 휩쓸기: 배에서 첫 대상 쪽으로 deg 부채꼴 안, (첫 대상 거리 + range) 안의 조준 가능한 적을 모두 같은 비율로.
Volley _sweep(Gun g, Volley v, List<Foe> foes, BattleGeometry geo, ({double deg, double range}) s) {
  final ship = geo.viewShip;
  if (ship == null) return v; // 옆모습은 그대로
  final first = v.hits.first.foe;
  final aim = math.atan2(first.y - ship.y, first.x - ship.x);
  final reach = math.sqrt(math.pow(first.x - ship.x, 2) + math.pow(first.y - ship.y, 2)) + s.range;
  final halfArc = s.deg * radiansPerDegree * half;
  final hit = [for (final h in v.hits) h.foe];
  for (final e in geo.eligible(g.attack, foes)) {
    if (hit.contains(e)) continue;
    final dx = e.x - ship.x;
    final dy = e.y - ship.y;
    if (dx * dx + dy * dy > reach * reach) continue;
    var d = math.atan2(dy, dx) - aim;
    d = math.atan2(math.sin(d), math.cos(d));
    if (d.abs() <= halfArc) hit.add(e);
  }
  return (x: v.x, y: v.y, hits: [for (final e in hit) (foe: e, factor: v.hits.first.factor)]);
}

/// 한 발이 맞은 뒤: 부메랑(saw) · 물기 속박(bara) · 해적왕 강타(davy).
void traitsAfterHit(Round r, Gun g, Volley v, BigNum base) {
  final l = g.legend;
  if (l == null || v.hits.isEmpty) return;
  if (l.boomerang > 0) {
    // 같은 길로 돌아오며 아직 살아 있는 적에게 한 번 더(렌더는 돌아오는 탄 — S3).
    final back = [
      for (final h in v.hits)
        if (h.foe.alive) h,
    ];
    if (back.isNotEmpty) r.strike((x: v.x, y: v.y, hits: back), base.times(l.boomerang), crewId: g.crewId);
  }
  if (l.bindSec > 0) {
    for (final h in v.hits) {
      final e = h.foe;
      if (!e.alive) continue;
      final sec = l.bindSec * (e.boss ? r.t.skills.bossControlFactor : 1);
      e.rootTimer = math.max(e.rootTimer, sec);
    }
  }
  if (l.bossBonus > 0) {
    final bosses = [
      for (final h in v.hits)
        if (h.foe.alive && (h.foe.boss || h.foe.ownerId != null)) h,
    ];
    if (bosses.isNotEmpty) r.strike((x: v.x, y: v.y, hits: bosses), base.times(l.bossBonus), crewId: g.crewId);
  }
}

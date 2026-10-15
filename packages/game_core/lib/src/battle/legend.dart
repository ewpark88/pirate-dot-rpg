import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/battle/topdown/geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_data/game_data.dart';

// 전설 고유 능력의 효과 부품 (docs/specs/battle-m3-legend.md).

/// extraChains·noFalloff: 마지막 대상에서 가까운 적으로 더 잇고, 비율을 다시 매긴다.
Volley extendVolley(Gun g, Volley v, List<Foe> foes, WavesTable w, {BattleGeometry? geometry}) {
  final l = g.legend;
  if (l == null || (l.extraChains == 0 && !l.noFalloff) || v.hits.isEmpty) return v;
  final hit = [for (final h in v.hits) h.foe];
  final pool = (geometry ?? SideGeometry(w)).eligible(g.attack, foes).where((e) => !hit.contains(e)).toList();
  for (var i = 0; i < l.extraChains && pool.isNotEmpty; i++) {
    final last = hit.last;
    final next = pool.reduce((m, e) => _d2(e, last) < _d2(m, last) ? e : m);
    hit.add(next);
    pool.remove(next);
  }
  final hadFalloff = v.hits.length > 1 && v.hits[1].factor < v.hits[0].factor;
  final falloff = !l.noFalloff && (hadFalloff || l.extraChains > 0);
  return (x: v.x, y: v.y, hits: spread(hit, w, falloff: falloff));
}

/// 맞은 적에게 onHit 효과. 보스는 기절·끌어당김·감속을 bossControlFactor만큼.
void applyOnHit(Round r, Gun g, Iterable<Foe> foes, BigNum amount, {required double x, required double y}) {
  final oh = g.legend?.onHit;
  if (oh == null) return;
  for (final e in foes) {
    if (!e.alive) continue;
    final k = e.boss ? r.t.skills.bossControlFactor : 1.0;
    if (oh.slow > 0) {
      e
        ..slow = math.max(e.slow, oh.slow * k)
        ..slowTimer = math.max(e.slowTimer, oh.slowSec);
    }
    if (oh.burnSec > 0) {
      final ticks = math.max((oh.burnSec / r.dt).round(), 1);
      e
        ..burnTicks = ticks
        ..burnPerTick = amount.times(oh.burnRatio / ticks)
        ..burnCrewId = g.crewId;
    }
    if (oh.stunSec > 0) e.stunTimer = math.max(e.stunTimer, oh.stunSec * k);
    if (oh.vulnerable > 0) {
      e
        ..vulnerable = math.max(e.vulnerable, oh.vulnerable)
        ..vulnerableTimer = math.max(e.vulnerableTimer, oh.vulnerableSec);
    }
    if (oh.pull != 0) {
      r.geo.pull(e, x, y, oh.pull * k);
    }
  }
}

/// 전설 장판(피해 없음): 감속·주기 기절.
void spawnLegendZone(Round r, Gun g, double x, double y) {
  final z = g.legend?.zone;
  if (z == null) return;
  final ticks = math.max((z.sec / r.dt).round(), 1);
  r.field.zones.add(
    Zone(
      crewId: g.crewId,
      x: x,
      y: y,
      radius: z.radius,
      ticksLeft: ticks,
      perTick: BigNum.zero,
      excludeLayers: const {},
      slow: z.slow,
      stunEveryTicks: (z.stunEverySec / r.dt).round(),
      stunSec: z.stunSec,
    ),
  );
  r.ctx.emit(ZoneSpawned(r.ctx.tick, crewId: g.crewId, x: x, y: y, radius: z.radius, ticks: ticks));
}

/// 치명타일 때 조준점 주변(critBurst 반경)의 다른 적에게 base × critBurstDamage.
void critBurst(Round r, Gun g, Volley v, BigNum base, {required bool crit}) {
  final radius = g.legend?.critBurst ?? 0;
  if (!crit || radius <= 0) return;
  final hitIds = {for (final h in v.hits) h.foe.id};
  final around = [
    for (final e in r.geo.eligible(g.attack, r.field.foes))
      if (!hitIds.contains(e.id) && (e.x - v.x) * (e.x - v.x) + (e.y - v.y) * (e.y - v.y) <= radius * radius) e,
  ];
  if (around.isEmpty) return;
  r.strike((x: v.x, y: v.y, hits: spread(around, r.w)), base.times(r.t.skills.critBurstDamage), crewId: g.crewId);
}

/// 한 발이 끝난 뒤 전설 능력: onHit, 장판, 치명타 폭발.
void legendAfterHit(Round r, Gun g, Volley v, BigNum base, {required bool crit}) {
  if (g.legend == null) return;
  applyOnHit(r, g, v.hits.map((h) => h.foe), base, x: v.x, y: v.y);
  spawnLegendZone(r, g, v.x, v.y);
  critBurst(r, g, v, base, crit: crit);
}

double _d2(Foe a, Foe b) => (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y);

extension LegendRound on Round {
  /// 매 틱: 화상 피해.
  void tickStatus() {
    for (final e in List.of(field.foes)) {
      if (!e.alive || e.burnTicks <= 0) continue;
      e.burnTicks -= 1;
      strike((x: e.x, y: e.y, hits: [(foe: e, factor: 1.0)]), e.burnPerTick, crewId: e.burnCrewId);
    }
  }
}

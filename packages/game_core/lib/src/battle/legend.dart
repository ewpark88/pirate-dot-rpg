import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/battle/topdown/geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

// 전설 고유 능력의 효과 부품 (docs/specs/battle-m3-legend.md).

/// 특징(전설 미만)의 '발마다 확률': [chance]가 0보다 크면 결정론 난수로 굴린다(0이면 난수를 쓰지 않는다 — 옛 결과 그대로).
bool roll(double chance, Rng rng) => chance > 0 && rng.nextDouble() < chance;

/// 한 번 발사의 발 수(한 발 피해 = 한 번 피해 ÷ 이 수): 원형 탄막은 ringCount(등급 ladder), 그 밖은 projectiles + 전설·특징 추가.
int shotCount(Gun g, Rng rng) {
  final a = g.attack;
  if (a.shape == 'ring') return a.raw.numberOr('ringCount', a.projectiles.toDouble()).round();
  return a.projectiles + extraShots(g, rng);
}

/// 발사체 추가 수: 전설 extraProjectiles + 특징 확률 몫.
int extraShots(Gun g, Rng rng) {
  final l = g.legend;
  if (l == null) return 0;
  return l.extraProjectiles + (roll(l.extraProjectilesChance, rng) ? 1 : 0);
}

/// extraChains·noFalloff: 마지막 대상에서 가까운 적으로 더 잇고, 비율을 다시 매긴다.
Volley extendVolley(
  Gun g,
  Volley v,
  List<Foe> foes,
  WavesTable w, {
  required BattleGeometry geometry,
  required Rng rng,
}) {
  final l = g.legend;
  if (l == null || v.hits.isEmpty) return v;
  final extraChains = l.extraChains + (roll(l.extraChainsChance, rng) ? 1 : 0);
  final noFalloff = l.noFalloff || roll(l.noFalloffChance, rng);
  if (extraChains == 0 && !noFalloff) return v;
  final hit = [for (final h in v.hits) h.foe];
  final pool = geometry.eligible(g.attack, foes).where((e) => !hit.contains(e)).toList();
  for (var i = 0; i < extraChains && pool.isNotEmpty; i++) {
    final last = hit.last;
    final next = pool.reduce((m, e) => _d2(e, last) < _d2(m, last) ? e : m);
    hit.add(next);
    pool.remove(next);
  }
  final hadFalloff = v.hits.length > 1 && v.hits[1].factor < v.hits[0].factor;
  final falloff = !noFalloff && (hadFalloff || extraChains > 0);
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

/// 번개 연쇄(개성 v2 7.2 낙뢰): 떨어진 자리에서 가까운 순으로 맞지 않은 적 count(+확률 1)마리에게 base × ratio, 기절.
void lightningArc(Round r, Gun g, Volley v, BigNum base) {
  final arc = g.legend?.arc;
  if (arc == null) return;
  final n = arc.count + (roll(arc.chance, r.ctx.rng) ? 1 : 0);
  if (n <= 0) return;
  final hitIds = {for (final h in v.hits) h.foe.id};
  double d2(Foe e) => (e.x - v.x) * (e.x - v.x) + (e.y - v.y) * (e.y - v.y);
  final next = [
    for (final e in r.geo.eligible(g.attack, r.field.foes))
      if (!hitIds.contains(e.id)) e,
  ]..sort((p, q) => d2(p).compareTo(d2(q)));
  final hit = next.take(n).toList();
  if (hit.isEmpty) return;
  r
    ..strike((x: v.x, y: v.y, hits: spread(hit, r.w)), base.times(arc.ratio), crewId: g.crewId)
    ..control(hit, stunSec: arc.stunSec);
}

/// 맞은 자리 작은 폭발(사용자 '전설 상위·신화는 범위 공격과 막강한 임팩트' — aim.legend·aim.mythic의 splashRadius·splashRatio):
/// 조준점 반경 안 맞지 않은 적에게 base × splashRatio.
void splash(Round r, Gun g, Volley v, BigNum base) {
  final radius = g.attack.raw.numberOr('splashRadius', 0);
  if (radius <= 0) return;
  final hitIds = {for (final h in v.hits) h.foe.id};
  final around = [
    for (final e in r.geo.eligible(g.attack, r.field.foes))
      if (!hitIds.contains(e.id) && (e.x - v.x) * (e.x - v.x) + (e.y - v.y) * (e.y - v.y) <= radius * radius) e,
  ];
  if (around.isEmpty) return;
  r.strike(
    (x: v.x, y: v.y, hits: spread(around, r.w)),
    base.times(g.attack.raw.number('splashRatio')),
    crewId: g.crewId,
  );
}

/// 한 발이 끝난 뒤: 맞은 자리 폭발(등급), 전설 능력 onHit·장판·치명타 폭발·번개 연쇄.
void legendAfterHit(Round r, Gun g, Volley v, BigNum base, {required bool crit}) {
  splash(r, g, v, base);
  if (g.legend == null) return;
  applyOnHit(r, g, v.hits.map((h) => h.foe), base, x: v.x, y: v.y);
  spawnLegendZone(r, g, v.x, v.y);
  critBurst(r, g, v, base, crit: crit);
  lightningArc(r, g, v, base);
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

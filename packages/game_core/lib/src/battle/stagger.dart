import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/flight.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_data/game_data.dart';

/// 계열 행동 v3 시차 타격 — 한 번 쏜 피해를 눈에 보이게 나눠 친다(attack.behavior):
/// - burst n · burstGapSec(직사 기관포): 같은 대상에게 한 발 피해 ÷ n을 간격마다 n번.
/// - hopSec(물수제비): 연쇄 k번째 대상을 k × hopSec 뒤에(통통 튕김).
/// - ringSpeed(충격 파동 링): 각 대상이 배 둘레에서 떨어진 만큼(가장자리 거리 ÷ 링 속도) 늦게.
/// 탄 비행(projectile)이 있는 공격은 여기서 다루지 않는다. 전설 능력은 첫 타에만.
extension Staggered on Round {
  ({Volley volley, int ticks})? launchStaggered(Gun g, AttackDef a, Volley v, BigNum base, {required bool crit}) {
    final geo = this.geo;
    if (!a.raw.has('behavior') || a.projectile != null || geo is! TopGeometry || v.hits.isEmpty) return null;
    final b = a.raw.obj('behavior');
    final hits = <({int at, List<Hit> hits, BigNum base})>[];
    if (b.has('burst')) {
      final n = b.integer('burst');
      final gap = b.number('burstGapSec');
      for (var i = 0; i < n; i++) {
        hits.add((at: (i * gap / dt).round(), hits: v.hits, base: base.times(1 / n)));
      }
    } else if (b.has('hopSec')) {
      for (var i = 0; i < v.hits.length; i++) {
        hits.add((at: (i * b.number('hopSec') / dt).round(), hits: [v.hits[i]], base: base));
      }
    } else if (b.has('ringSpeed')) {
      for (final h in v.hits) {
        final at = (math.max(0, geo.edge(h.foe)) / b.number('ringSpeed') / dt).round();
        hits.add((at: at, hits: [h], base: base));
      }
    } else {
      return null;
    }
    var last = 0;
    for (var i = 0; i < hits.length; i++) {
      final s = hits[i];
      last = math.max(last, s.at);
      field.flights.add(
        Flight(
          gun: g,
          attack: a,
          volley: (x: s.hits.first.foe.x, y: s.hits.first.foe.y, hits: s.hits),
          base: s.base,
          crit: crit,
          arriveTick: ctx.tick + s.at,
          fixed: true,
          afterHit: i == 0,
        ),
      );
    }
    return (volley: v, ticks: last);
  }
}

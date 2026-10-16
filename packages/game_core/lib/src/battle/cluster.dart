import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/flight.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

/// 집속탄(계열 행동 v3 — 사용자 '큰 폭탄 하나 → 터진 주변에 작은 폭탄 여러 발이 산개해 연쇄로 터짐, 등급별 자탄 수↑'):
/// 본탄이 맞은 뒤(즉시든 날아서든) 자탄 bomblets(등급 ladder)발을 scatterRadius 안에 흩뿌리고 bombletDelaySec 간격으로 차례로 터뜨린다.
/// 자탄 하나 = 반경 bombletRadius 원, 피해 = 한 발 피해 × bombletRatio ÷ 자탄 수. 자탄은 전설 능력·또 다른 자탄을 부르지 않는다.
void scatterBomblets(Round r, Gun g, Volley v, BigNum base) {
  final a = g.attack;
  if (a.shape != 'cluster' || !a.raw.has('behavior')) return;
  final b = a.raw.obj('behavior');
  final k = a.raw.numberOr('bomblets', 0).round();
  if (k <= 0) return;
  final bomblet = AttackDef.fromJson(
    JsonReader(
      {
        ...a.raw.raw,
        'shape': 'circle',
        'topRadius': b.number('bombletRadius'),
        'bomblet': true,
        'dotSec': 0,
      }..remove('projectile'),
      a.raw.path,
    ),
  );
  final each = base.times(b.numberOr('bombletRatio', 1) / k);
  final gap = math.max(1, (b.number('bombletDelaySec') / r.dt).round());
  final spread = b.number('scatterRadius');
  for (var i = 0; i < k; i++) {
    final angle = r.ctx.rng.nextDouble() * math.pi / half;
    final dist = spread * math.sqrt(r.ctx.rng.nextDouble()); // 원 안 고르게(결정론 난수)
    r.field.flights.add(
      Flight(
        gun: g,
        attack: bomblet,
        volley: (x: v.x + math.cos(angle) * dist, y: v.y + math.sin(angle) * dist, hits: const <Hit>[]),
        base: each,
        crit: false,
        arriveTick: r.ctx.tick + gap * (i + 1),
      ),
    );
  }
}

/// 자탄인가(전설 능력·연쇄 자탄을 부르지 않는다).
bool isBomblet(AttackDef a) => a.raw.raw['bomblet'] == true;

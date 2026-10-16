import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/legend.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_data/game_data.dart';

/// 유지되는 레이저 빔 (계열 행동 v3 레이저 — 사용자 '직선 레이저 빔 0.3~0.6초, 관통 수가 등급별'). 배에서 (ux, uy) 방향.
class Beam {
  Beam({
    required this.gun,
    required this.attack,
    required this.ux,
    required this.uy,
    required this.perTick,
    required this.base,
    required this.crit,
    required this.until,
  });

  final Gun gun;
  final AttackDef attack;
  final double ux;
  final double uy;

  /// 한 틱 피해(한 발 피해 ÷ 빔 틱).
  final BigNum perTick;
  final BigNum base;
  final bool crit;

  /// 이 틱 전까지 빔이 있다.
  final int until;

  /// 전설 능력(onHit 등)은 첫 틱에 한 번만.
  bool first = true;
}

/// 레이저 계열인가(attack.behavior.kind 'laser').
bool isBeam(AttackDef a) => a.raw.has('behavior') && a.raw.obj('behavior').str('kind') == 'laser';

extension Beams on Round {
  /// 레이저면 빔을 세우고 빔 틱을 돌려준다(AttackFired.beamTicks). 아니면 null.
  ({Volley volley, int ticks})? launchBeam(Gun g, AttackDef a, Volley v, BigNum base, {required bool crit}) {
    final geo = this.geo;
    if (!isBeam(a) || geo is! TopGeometry) return null;
    final ticks = math.max(1, (a.raw.obj('behavior').number('beamSec') / dt).round());
    final dx = v.x - geo.top.shipX;
    final dy = v.y - geo.top.shipY;
    final len = math.sqrt(dx * dx + dy * dy);
    field.beams.add(
      Beam(
        gun: g,
        attack: a,
        ux: len == 0 ? 0 : dx / len,
        uy: len == 0 ? -1 : dy / len,
        perTick: base.times(1 / ticks),
        base: base,
        crit: crit,
        until: ctx.tick + ticks,
      ),
    );
    return (volley: v, ticks: ticks);
  }

  /// 매 틱: 빔마다 지금 배 자리에서 광선 위 적(관통 수만큼, 감쇠 없음)에게 한 틱 피해. 배가 움직이면 빔도 따라간다.
  void tickBeams() {
    final geo = this.geo;
    if (field.beams.isEmpty || geo is! TopGeometry) return;
    field.beams.removeWhere((b) => b.until <= ctx.tick);
    for (final b in field.beams) {
      final hit = geo.beamHits(b.attack, b.ux, b.uy, field.foes);
      if (hit.isEmpty) continue;
      final v = (x: hit.last.x, y: hit.last.y, hits: [for (final e in hit) (foe: e, factor: 1.0)]);
      strike(v, b.perTick, crit: b.crit, crewId: b.gun.crewId);
      if (b.first) {
        b.first = false;
        legendAfterHit(this, b.gun, v, b.base, crit: b.crit);
      }
    }
  }
}

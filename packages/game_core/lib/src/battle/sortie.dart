import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/legend.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_data/game_data.dart';

/// 출격 중인 선원 (계열 행동 v3 — 강습·공중: 선원 본인이 날아가 꽂히고 돌아온다, docs/specs/platform-family-behavior-v3.md).
class Sortie {
  Sortie({required this.attack, required this.base, required this.crit, required this.x, required this.y});

  final AttackDef attack;
  final BigNum base;
  final bool crit;

  /// 꽂힐 자리(첫 발의 조준점).
  final double x;
  final double y;

  /// 이번 출격의 발들(발사체 +n이면 여럿 — 한 번에 휘두른다).
  final List<Volley> volleys = [];

  /// out(날아감) · strike(휘두름) · back(돌아옴).
  String phase = 'out';

  /// 이 단계가 끝나는 틱.
  int until = 0;
}

extension Sorties on Round {
  /// [a]가 출격 계열(attack.behavior.kind 'sortie')이면 출격을 시작하고(같은 발사의 다음 발은 같은 출격에 더함) 날아가는 틱을 돌려준다.
  /// 아니면 null. 피해는 strike 순간에, 다음 공격 쿨은 돌아온 뒤에 시작한다.
  ({Volley volley, int ticks})? launchSortie(Gun g, AttackDef a, Volley v, BigNum base, {required bool crit}) {
    final b = a.raw.has('behavior') ? a.raw.obj('behavior') : null;
    final geo = this.geo;
    if (b == null || b.str('kind') != 'sortie' || geo is! TopGeometry) return null;
    final out = _ticks(b.number('outSec'));
    final now = g.sortie;
    if (now != null) {
      now.volleys.add(v);
      return (volley: v, ticks: out);
    }
    final s = Sortie(attack: a, base: base, crit: crit, x: v.x, y: v.y)
      ..volleys.add(v)
      ..until = ctx.tick + out;
    g.sortie = s;
    final from = geo.muzzle(v.x, v.y);
    ctx.emit(
      CrewSortie(
        ctx.tick,
        crewId: g.crewId,
        phase: 'out',
        fromX: from.x,
        fromY: from.y,
        toX: v.x,
        toY: v.y,
        ticks: out,
      ),
    );
    return (volley: v, ticks: out);
  }

  /// 매 틱: 출격 단계를 넘긴다. out 끝 = 꽂혀 피해(조준한 적이 죽었으면 그 자리 가장 가까운 적, 없으면 MISS) → strike 끝 = 복귀 → back 끝 = 쿨 시작.
  void tickSorties() {
    final geo = this.geo;
    if (geo is! TopGeometry) return;
    for (final g in field.guns) {
      final s = g.sortie;
      if (s == null) continue;
      if (ctx.tick < s.until) continue;
      final b = s.attack.raw.obj('behavior');
      switch (s.phase) {
        case 'out':
          _strike(g, s, geo);
          final strike = _ticks(b.number('strikeSec'));
          s
            ..phase = 'strike'
            ..until = ctx.tick + strike;
          ctx.emit(
            CrewSortie(
              ctx.tick,
              crewId: g.crewId,
              phase: 'strike',
              fromX: s.x,
              fromY: s.y,
              toX: s.x,
              toY: s.y,
              ticks: strike,
            ),
          );
        case 'strike':
          final home = geo.muzzle(s.x, s.y);
          final back = _ticks(b.number('backSec'));
          s
            ..phase = 'back'
            ..until = ctx.tick + back;
          ctx.emit(
            CrewSortie(
              ctx.tick,
              crewId: g.crewId,
              phase: 'back',
              fromX: s.x,
              fromY: s.y,
              toX: home.x,
              toY: home.y,
              ticks: back,
            ),
          );
        default:
          g
            ..sortie = null
            ..cooldown = s.attack.intervalSec; // 쿨은 돌아온 뒤부터
      }
    }
  }

  void _strike(Gun g, Sortie s, TopGeometry geo) {
    for (final v in s.volleys) {
      var hits = [
        for (final h in v.hits)
          if (h.foe.alive) h,
      ];
      if (hits.isEmpty) {
        // 조준한 적이 이미 쓰러졌다 — 꽂힌 자리에서 가장 가까운 적(보이는 화면 안), 없으면 헛스윙.
        double d2(Foe e) => (e.x - v.x) * (e.x - v.x) + (e.y - v.y) * (e.y - v.y);
        final pool = geo.eligible(s.attack, field.foes);
        if (pool.isEmpty) {
          ctx.emit(AttackMissed(ctx.tick, crewId: g.crewId, x: v.x, y: v.y));
          continue;
        }
        hits = [(foe: pool.reduce((m, e) => d2(e) < d2(m) ? e : m), factor: 1.0)];
      }
      final landed = (x: v.x, y: v.y, hits: hits);
      land(g, s.attack, landed, s.base, crit: s.crit);
      legendAfterHit(this, g, landed, s.base, crit: s.crit);
    }
  }

  int _ticks(double sec) => math.max(1, (sec / dt).round());
}

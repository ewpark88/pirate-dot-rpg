import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show spawnWave;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_data/game_data.dart';

/// 보스 행동 v2 (docs/specs/platform-boss-patterns.md): 쉼 → 예고 → 동작을 패턴 순서대로 돈다.
class BossPlan {
  BossPlan(this.patterns, this.restTicks) : ticksLeft = restTicks;

  final List<BossPatternDef> patterns;
  final int restTicks;
  int index = 0;

  /// rest(기본 원거리 공격) · warn(예고) · charge(돌진 중) · back(standoff로 돌아감).
  String phase = 'rest';
  int ticksLeft;

  BossPatternDef get current => patterns[index];

  /// 돌진·복귀 중: 보통 이동·standoff 돌기를 하지 않는다.
  bool get steering => phase == 'charge' || phase == 'back';

  /// 쉼이 아니면 기본 원거리 공격을 쉬고 패턴에 집중한다.
  bool get busy => phase != 'rest';
}

extension BossPatterns on Round {
  /// 매 틱: 패턴이 있는 보스(살아 있는)마다 한 단계. 기절 중엔 멈추고, 예고 중 기절되면 그 패턴은 취소.
  void tickBossPatterns() {
    final g = geo;
    if (g is! TopGeometry) return;
    for (final e in field.living.toList()) {
      // 소환이 적을 더하니 사본으로
      final plan = e.plan;
      if (plan == null) continue;
      if (e.stunned) {
        if (plan.phase == 'warn') {
          _emit(e, plan.current, 'cancel', g);
          _next(plan);
        }
        continue;
      }
      if (plan.phase == 'charge') {
        _charge(e, plan, g);
      } else if (plan.phase == 'back') {
        final d = _dist(e, g);
        final step = e.speed * plan.current.speedMul * dt * g.speedScale;
        var out = g.top.bossStandoff - d; // standoff까지 남은 거리만큼만
        if (out > step) out = step;
        if (out < 0) out = 0;
        _moveToward(e, g, -out);
        if (d + step >= g.top.bossStandoff) _next(plan);
      } else {
        plan.ticksLeft -= 1;
        if (plan.ticksLeft > 0) continue;
        if (plan.phase == 'rest') {
          plan
            ..phase = 'warn'
            ..ticksLeft = math.max(1, (plan.current.warnSec / dt).round());
          _emit(e, plan.current, 'warn', g, warnTicks: plan.ticksLeft);
        } else {
          _act(e, plan, g);
        }
      }
    }
  }

  void _act(Foe e, BossPlan plan, TopGeometry g) {
    final p = plan.current;
    _emit(e, p, 'act', g);
    switch (p.type) {
      case 'volley':
        // 부채꼴은 연출(spreadDeg) — 배는 움직이지 않으니 모든 탄이 배에 닿는다. 발마다 공격 × damageRatio(한 대 상한).
        final gap = math.max(0, g.hullGap(e.x, e.y) - g.top.radiusOf(e));
        final flight = math.max(1, (gap / p.speed / dt).round());
        for (var i = 0; i < p.count; i++) {
          field.enemyShots.add(
            EnemyShot(ticksLeft: flight + i, amount: e.attack.times(p.damageRatio), fromX: e.x, fromY: e.y),
          );
          ctx.emit(
            EnemyFired(ctx.tick, enemyId: e.id, fromX: e.x, fromY: e.y, flightTicks: flight + i, kind: 'boss_shell'),
          );
        }
        _next(plan);
      case 'charge':
        plan.phase = 'charge';
      case 'summon':
        spawnWave(field, field.stage, ctx, count: p.count);
        _next(plan);
      default: // blast: 예고한 배 둘레 원이 터진다
        _hurt(e, p);
        _next(plan);
    }
  }

  /// 돌진: 배로 곧장(속도 × speedMul) — 몸통에 닿으면 큰 피해 한 번, 그다음 standoff로 돌아간다.
  void _charge(Foe e, BossPlan plan, TopGeometry g) {
    final p = plan.current;
    _moveToward(e, g, e.speed * p.speedMul * dt * g.speedScale);
    if (g.hullGap(e.x, e.y) > g.top.radiusOf(e)) return;
    _hurt(e, p);
    plan.phase = 'back';
  }

  void _hurt(Foe e, BossPatternDef p) {
    if (invincible) return;
    final amount = field.hurtShip(e.attack.times(p.damageRatio), w.raw.number('shipHitCap') * p.capMul);
    ctx.emit(
      ShipDamaged(
        ctx.tick,
        amount: amount,
        hpRatio: (field.shipHp / field.shipHpMax).toDouble(),
        fromX: e.x,
        fromY: e.y,
      ),
    );
  }

  void _next(BossPlan plan) {
    plan
      ..index = (plan.index + 1) % plan.patterns.length
      ..phase = 'rest'
      ..ticksLeft = plan.restTicks;
  }

  void _emit(Foe e, BossPatternDef p, String phase, TopGeometry g, {int warnTicks = 0}) => ctx.emit(
    BossPatternShown(
      ctx.tick,
      enemyId: e.id,
      kind: p.type,
      phase: phase,
      warnTicks: warnTicks,
      x: e.x,
      y: e.y,
      angle: math.atan2(g.top.shipY - e.y, g.top.shipX - e.x),
      count: p.count,
      radius: g.top.shipRadius * p.radiusShipMul,
    ),
  );

  double _dist(Foe e, TopGeometry g) =>
      math.sqrt(math.pow(e.x - g.top.shipX, 1 + 1) + math.pow(e.y - g.top.shipY, 1 + 1));

  /// 배 중심 쪽으로 [step]만큼(음수면 바깥으로).
  void _moveToward(Foe e, TopGeometry g, double step) {
    final d = _dist(e, g);
    if (d <= 0) return;
    e
      ..x += (g.top.shipX - e.x) / d * step
      ..y += (g.top.shipY - e.y) / d * step;
  }
}

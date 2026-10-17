import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show spawnWave;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

/// 보스 행동 v2 (docs/specs/platform-boss-patterns.md): 쉼 → 예고 → 동작을 패턴 순서대로 돈다.
class BossPlan {
  BossPlan(this.patterns, this.restTicks, {int? firstTicks}) : ticksLeft = firstTicks ?? restTicks;

  final List<BossPatternDef> patterns;
  int restTicks; // 분노(보스 특성 enrage)가 줄인다
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
    _inkAndSplit(g);
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
        // 일제 사격은 쏘기 직전(waves.top.windupSec) 예고 — 렌더가 포문을 밝힌다. 예고가 그보다 짧으면 예고 시작 때.
        if (plan.phase == 'warn' &&
            plan.current.type == 'volley' &&
            _windupTicks > 0 &&
            plan.ticksLeft == _windupTicks) {
          ctx.emit(EnemyWindup(ctx.tick, enemyId: e.id, atTicks: plan.ticksLeft, kind: 'volley'));
        }
        if (plan.ticksLeft > 0) continue;
        if (plan.phase == 'rest') {
          plan
            ..phase = 'warn'
            ..ticksLeft = math.max(1, (plan.current.warnSec / dt).round());
          _emit(e, plan.current, 'warn', g, warnTicks: plan.ticksLeft);
          if (plan.current.type == 'volley' && _windupTicks > 0 && plan.ticksLeft < _windupTicks) {
            ctx.emit(EnemyWindup(ctx.tick, enemyId: e.id, atTicks: plan.ticksLeft, kind: 'volley'));
          }
        } else {
          _act(e, plan, g);
        }
      }
    }
  }

  /// 쏘기 직전 예고 틱 수(0이면 없음).
  int get _windupTicks => (w.raw.obj('top').numberOr('windupSec', 0) / dt).round();

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
      case 'ink':
        // 먹물(도감 v2): 보스와 배 사이 원 — 그 안 적은 durationSec 동안 조준되지 않는다
        final ticks = math.max(1, (p.durationSec / dt).round());
        final ink = (
          x: (e.x + g.top.shipX) * half,
          y: (e.y + g.top.shipY) * half,
          r: g.top.shipRadius * p.radiusShipMul,
          until: ctx.tick + ticks,
        );
        field.inks.add(ink);
        ctx.emit(InkCloud(ctx.tick, enemyId: e.id, x: ink.x, y: ink.y, radius: ink.r, ticks: ticks));
        _next(plan);
      case 'swallow':
        // 삼키기(도감 v2): 보스 둘레 원 안 잡몹을 삼켜(보상 없음) 마리당 최대 HP × healRatio 회복 — 먼저 잡으면 막는다
        final r = g.top.shipRadius * p.radiusShipMul + g.top.radiusOf(e);
        final eaten = [
          for (final m in field.living)
            if (!m.standsOff && m.eventKind == null && m.ownerId == null && _gap(m, e) <= r) m, // 호위·촉수는 안 먹는다
        ];
        field.foes.removeWhere(eaten.contains);
        final healed = e.maxHp.times(p.healRatio * eaten.length);
        final hp = e.hp + healed;
        e.hp = hp > e.maxHp ? e.maxHp : hp;
        ctx.emit(BossSwallowed(ctx.tick, enemyId: e.id, eaten: [for (final m in eaten) m.id], healed: healed));
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

  /// 먹물 구름 정리·조준 가림 갱신, 분열(BossDef.splitAt — HP 비율이 문턱 아래로 내려갈 때마다 둘로).
  void _inkAndSplit(TopGeometry g) {
    field.inks.removeWhere((i) => i.until <= ctx.tick);
    g.targeting.blinds = List.of(field.inks);
    for (final e in field.living.toList()) {
      final at = e.bossDef?.splitAt ?? const <double>[];
      if (!e.boss || e.splits >= at.length || (e.hp / e.maxHp).toDouble() > at[e.splits]) continue;
      final halfHp = e.hp.times(half);
      final child =
          Foe(
              id: field.nextId(),
              kind: e.kind,
              layer: e.layer,
              x: e.x + g.top.radiusOf(e) / half,
              y: e.y,
              maxHp: e.maxHp,
              speed: e.speed,
              attack: e.attack,
              gold: BigNum.zero, // 처치 골드는 원래 몸 하나
              boss: true,
              bossDef: e.bossDef,
              tier: e.tier,
            )
            ..splits = e.splits + 1
            ..hp = halfHp
            ..breakCooldownUntil = e
                .breakCooldownUntil // 분열한 몸도 부모의 브레이크 쿨다운을 이어받는다(S5 참고)
            ..breakCooldownTicks = e.breakCooldownTicks
            ..breakCooldownRatio = e.breakCooldownRatio
            ..enraged = e.enraged; // 보스 특성 상태도(호위를 다시 부르거나 분노가 다시 걸리지 않게)
      child.traitTicks.addAll(e.traitTicks);
      e
        ..hp = halfHp
        ..splits += 1;
      field.foes.add(child);
      ctx.emit(BossSplit(ctx.tick, parentId: e.id, childId: child.id, x: child.x, y: child.y));
    }
  }

  double _gap(Foe a, Foe b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
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

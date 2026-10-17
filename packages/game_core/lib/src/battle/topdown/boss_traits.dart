import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/legend.dart' show missProof;
import 'package:game_core/src/battle/spawner.dart' show spawnWave;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

// 보스 특성 (docs/specs/economy-boss-traits.md, 사용자 요청 #25 — 승인 2026-10-17). 수치·카운터는 regions.json bossTraits(기본)
// 위에 보스별 traits 덮어쓰기. 특성이 없는 보스는 지금과 바이트까지 같다(난수는 회피 보스에게 맞을 때만 쓴다).

extension BossTraits on Round {
  int _ticks(double sec) => math.max(1, (sec / dt).round());

  /// strike 안: 보스 [e]가 [crewId]의 한 방 [amount]에서 실제로 받는 피해. null = 이번엔 안 맞음(회피·반사막).
  /// 선원이 아닌 피해(빠른 항해 돌파 사격·피버 오라 등, crewId null)는 특성을 지나간다 — 특성은 편성의 카운터 문제다.
  BigNum? traitHit(Foe e, BigNum amount, {String? crewId, bool crit = false}) {
    final def = e.bossDef;
    if (!e.boss || def == null || def.traits.isEmpty || crewId == null) return amount;
    final family = familyOf(crewId);
    final ev = def.trait('evade');
    if (ev != null) {
      final gun = field.guns.where((g) => g.crewId == crewId).firstOrNull;
      final p = ev.cfg.strs('dodge').contains(family) ? ev.cfg.numberOr('chance', 0) : ev.cfg.numberOr('areaChance', 0);
      if (p > 0 && !(gun != null && missProof(gun, ctx.rng)) && ctx.rng.nextDouble() < p) {
        ctx.emit(AttackMissed(ctx.tick, crewId: crewId, x: e.x, y: e.y, reason: 'evade'));
        return null;
      }
    }
    final rf = def.trait('reflect');
    if (rf != null && ctx.tick < (e.traitTicks['reflectUntil'] ?? 0) && !rf.cfg.strs('bypass').contains(family)) {
      if (!invincible) {
        final hurt = field.hurtShip(amount.times(rf.cfg.number('ratio')), w.raw.number('shipHitCap'));
        ctx.emit(
          ShipDamaged(
            ctx.tick,
            amount: hurt,
            hpRatio: (field.shipHp / field.shipHpMax).toDouble(),
            fromX: e.x,
            fromY: e.y,
          ),
        );
      }
      return null;
    }
    var out = amount;
    final es = def.trait('escort');
    if (es != null && field.living.any((x) => x.ownerId == e.id)) out = out.times(es.cfg.number('damageMul'));
    final ar = def.trait('armor');
    if (ar != null && !crit) {
      // 장갑: 느리고 센 공격(발사 간격 heavySec 이상)·치명타만 그대로, 빠른 작은 타격은 × factor.
      final gun = field.guns.where((g) => g.crewId == crewId).firstOrNull;
      if ((gun?.attack.intervalSec ?? 0) < ar.cfg.number('heavySec')) out = out.times(ar.cfg.number('factor'));
    }
    return out;
  }

  /// 매 틱: 재생 · 반사막 주기 · 분노 · 호위 소환 · 가속. 주인 보스가 쓰러진 호위는 보상 없이 사라진다.
  void tickBossTraits() {
    field.foes.removeWhere((x) => x.traitTicks.containsKey('guardOf') && !field.living.any((b) => b.id == x.ownerId));
    // 호위 소환이 적 목록을 늘리므로 보스만 먼저 뽑아 둔다.
    for (final e in [
      for (final x in field.living)
        if (x.boss && (x.bossDef?.traits.isNotEmpty ?? false)) x,
    ]) {
      final def = e.bossDef!;
      final t = e.traitTicks;
      final rg = def.trait('regen');
      if (rg != null && !e.stunned && e.brokenUntil == 0 && e.burnTicks <= 0 && e.hp < e.maxHp) {
        // fadeSec(선택): 보스전이 길어질수록 재생이 1 → 0으로 줄어든다 — 약한 함대(환생 직후 등)의 피해가 재생보다 작으면
        // 시간 제한이 없어 끝나지 않던 보스전(실기기 6-2 해파리 여왕 9.97K/10.3K, 2026-10-17). 회복 총량은 perSec × fadeSec / 2.
        final from = t['regenFrom'] ??= ctx.tick;
        final fade = rg.cfg.numberOr('fadeSec', 0);
        final k = fade <= 0 ? 1.0 : math.max(0, 1 - (ctx.tick - from) * dt / fade);
        final hp = e.hp + e.maxHp.times(rg.cfg.number('perSec') * dt * k);
        e.hp = hp > e.maxHp ? e.maxHp : hp;
      }
      final rf = def.trait('reflect');
      if (rf != null) {
        final at = t['reflectAt'] ??= ctx.tick + _ticks(rf.cfg.number('everySec'));
        final warn = _ticks(rf.cfg.number('warnSec'));
        if (ctx.tick == at - warn) {
          ctx.emit(
            BossTraitFired(ctx.tick, enemyId: e.id, trait: 'reflect', ticks: warn + _ticks(rf.cfg.number('sec'))),
          );
        }
        if (ctx.tick >= at) {
          t['reflectUntil'] = ctx.tick + _ticks(rf.cfg.number('sec'));
          t['reflectAt'] = ctx.tick + _ticks(rf.cfg.number('everySec'));
        }
      }
      final ratio = (e.hp / e.maxHp).toDouble();
      final en = def.trait('enrage');
      if (en != null && !e.enraged && ratio < en.cfg.number('below')) {
        e
          ..enraged = true
          ..attack = e.attack.times(en.cfg.number('attackMul'));
        final plan = e.plan;
        if (plan != null) plan.restTicks = math.max(1, (plan.restTicks * en.cfg.number('restMul')).round());
        ctx.emit(BossTraitFired(ctx.tick, enemyId: e.id, trait: 'enrage'));
      }
      final es = def.trait('escort');
      if (es != null) {
        final at = [for (final v in es.cfg.raw['at'] as List) (v as num).toDouble()];
        final done = t['escorts'] ?? 0;
        if (done < at.length && ratio <= at[done]) {
          t['escorts'] = done + 1;
          final before = field.foes.length;
          spawnWave(field, field.stage, ctx, count: es.cfg.integer('count'));
          _guard(e, field.foes.sublist(before));
          ctx.emit(BossTraitFired(ctx.tick, enemyId: e.id, trait: 'escort'));
        }
      }
      final da = def.trait('dash');
      if (da != null) _dash(e, da.cfg);
    }
  }

  /// 호위: 보스 둘레(보스 반경 + 잡몹 지름)에 고르게 세운다 — 촉수처럼 보스에 딸려 움직이지 않고 지킨다.
  void _guard(Foe boss, List<Foe> guards) {
    final g = geo;
    final r = g is TopGeometry ? g.top.bodyOf(boss) + g.top.mobRadius / half : 0.0;
    for (var i = 0; i < guards.length; i++) {
      final a = i * fullTurn / guards.length;
      guards[i]
        ..ownerId = boss.id
        ..x = boss.x + r * math.cos(a)
        ..y = boss.y + r * math.sin(a)
        ..traitTicks['guardOf'] = boss.id;
    }
  }

  /// 가속: everySec마다 sec 동안 배를 중심으로 deg만큼 돈다(보스와 배 거리는 그대로 — 사거리·패턴 불변). 기절 중엔 미룬다.
  void _dash(Foe e, JsonReader cfg) {
    final g = geo;
    if (g is! TopGeometry || e.stunned) return;
    final t = e.traitTicks;
    final at = t['dashAt'] ??= ctx.tick + _ticks(cfg.number('everySec'));
    final sec = _ticks(cfg.number('sec'));
    if (ctx.tick == at) ctx.emit(BossTraitFired(ctx.tick, enemyId: e.id, trait: 'dash', ticks: sec));
    if (ctx.tick < at) return;
    if (ctx.tick >= at + sec) {
      t['dashAt'] = ctx.tick + _ticks(cfg.number('everySec'));
      return;
    }
    final step = cfg.number('deg') * radiansPerDegree / sec;
    final dx = e.x - g.top.shipX;
    final dy = e.y - g.top.shipY;
    e
      ..x = g.top.shipX + dx * math.cos(step) - dy * math.sin(step)
      ..y = g.top.shipY + dx * math.sin(step) + dy * math.cos(step);
  }
}

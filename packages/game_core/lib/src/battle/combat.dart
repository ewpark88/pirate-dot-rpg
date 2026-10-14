import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

/// 한 틱 동안의 전투 계산. 지갑·게이지 변화는 [gold]·[rage]에 모아 두고 BattleSystem이 상태에 반영한다.
class Round {
  Round(this.field, this.ctx, this.stats, {required this.rage, this.invincible = false, this.zeroCooldown = false});

  final Field field;
  final SystemContext ctx;
  final CombatStats stats;
  final bool invincible;
  final bool zeroCooldown;

  /// 이번 틱에 번 골드 (화물칸·동시 처치 보너스 포함).
  BigNum gold = BigNum.zero;

  /// 함성 게이지 0~rageMax.
  double rage;

  GameTables get t => ctx.tables;
  WavesTable get w => t.waves;
  double get dt => w.tickMs * secondsPerMillisecond;

  /// 적 이동과 배 접촉 피해 (규칙 3).
  void moveFoes() {
    final f = w.field;
    for (final e in field.living) {
      if (e.x > f.shipX) {
        e.x = e.x - e.speed * dt < f.shipX ? f.shipX : e.x - e.speed * dt;
        continue;
      }
      e.contactTimer -= dt;
      if (e.contactTimer > 0) continue;
      e.contactTimer += f.contactIntervalSec;
      if (invincible) continue;
      final hp = field.shipHp - e.attack;
      field.shipHp = hp.isNegative ? BigNum.zero : hp;
      ctx.emit(ShipDamaged(ctx.tick, amount: e.attack, hpRatio: (field.shipHp / field.shipHpMax).toDouble()));
    }
  }

  /// 슬롯마다 쿨타임을 돌리고, 준비됐고 맞힐 적이 있으면 쏜다 (규칙 5).
  void fireGuns() {
    for (final g in field.guns) {
      g.cooldown -= dt * stats.attackSpeed;
      if (g.cooldown > 0 && !zeroCooldown) continue;
      final a = g.family.attack;
      final v = aim(a, field.foes, w, ctx.rng);
      if (v == null) {
        if (g.cooldown < 0) g.cooldown = 0;
        continue;
      }
      g.cooldown = a.intervalSec;
      ctx.emit(
        AttackFired(
          ctx.tick,
          crewId: g.crewId,
          family: g.family.id,
          targetIds: [for (final h in v.hits) h.foe.id],
          x: v.x,
          y: v.y,
        ),
      );
      final crit = ctx.rng.nextDouble() < stats.critChance;
      if (crit) _hitStop('crit');
      final base = stats.attack.times(g.power * stats.tierDamage * a.power * (crit ? stats.critMultiplier : 1));
      _strike(v, base, crit: crit, crewId: g.crewId);
      if (a.knockback > 0) {
        for (final h in v.hits) {
          if (!h.foe.boss) h.foe.x += a.knockback;
        }
      }
    }
  }

  /// 함성 게이지가 가득이면 선장의 궁극기: 화면의 모든 적 (규칙 7, M1 공통 모양).
  bool castUltimate() {
    final captain = field.captainId;
    if (rage < t.skills.rageMax || captain == null) return false;
    final gun = field.guns.firstWhere((g) => g.crewId == captain);
    final targets = [
      for (final e in field.foes)
        if (e.alive && e.x <= w.field.width) e,
    ];
    rage = 0;
    ctx.emit(UltimateCast(ctx.tick, crewId: captain, ultimateId: gun.family.ultimateId));
    _hitStop('ultimate');
    if (targets.isEmpty) return true;
    final base = stats.attack.times(gun.power * stats.tierDamage * t.skills.ultimateMultiplier);
    _strike((x: w.field.width * half, y: w.field.shipY, hits: spread(targets, w)), base, crewId: captain);
    return true;
  }

  /// 동시 처치 창을 닫는다 (규칙 7).
  void tickCombo() {
    if (field.comboKills == 0) return;
    field.comboTimer -= dt;
    if (field.comboTimer > 0) return;
    final n = field.comboKills;
    if (n >= w.multiKillMinKills) {
      gold = gold + field.comboGold.times(w.multiKillGoldBonusPerKill * n);
      ctx.emit(MultiKill(ctx.tick, count: n));
      if (n >= w.multiKillHitStopMinKills) _hitStop('multiKill4');
    }
    field
      ..comboKills = 0
      ..comboGold = BigNum.zero;
  }

  void _strike(Volley v, BigNum base, {bool crit = false, String? crewId}) {
    var total = BigNum.zero;
    for (final h in v.hits) {
      final e = h.foe;
      if (!e.alive) continue;
      final amount = base.times(h.factor);
      total = total + amount;
      e.hp = e.hp - amount;
      ctx.emit(Damage(ctx.tick, targetId: e.id, amount: amount, crit: crit, crewId: crewId));
      if (!e.alive) _kill(e);
    }
    if (v.hits.length > 1) ctx.emit(AoeDamageSum(ctx.tick, total: total, x: v.x, y: v.y));
  }

  void _kill(Foe e) {
    final g = e.gold.times(stats.goldMultiplier);
    gold = gold + g;
    ctx.emit(Kill(ctx.tick, targetId: e.id, gold: g, x: e.x, y: e.y));
    rage = rage + t.skills.ragePerKill > t.skills.rageMax ? t.skills.rageMax : rage + t.skills.ragePerKill;
    field
      ..comboKills += 1
      ..comboGold = field.comboGold + g
      ..comboTimer = w.multiKillWindowSec;
  }

  /// 히트스톱 틱 = juice.hitStopMs[이유] / tickMs (올림). 엔진이 이번 틱의 가장 긴 것을 건다.
  void _hitStop(String reason) {
    final ms = t.juice.hitStopMs[reason];
    if (ms == null) return;
    ctx.emit(HitStop(ctx.tick, ticks: (ms / w.tickMs).ceil(), reason: reason));
  }
}

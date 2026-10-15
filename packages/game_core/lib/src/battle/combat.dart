import 'dart:math' as math;

import 'package:game_core/src/battle/bosses.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/legend.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/battle/topdown/geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

/// 한 틱 동안의 전투 계산. 지갑·게이지 변화는 [gold]·[rage]에 모아 두고 BattleSystem이 상태에 반영한다.
/// 스킬·장판은 battle/skills.dart의 확장.
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

  /// 이번 틱에 처치한 수 (일일 퀘스트 '처치').
  int kills = 0;

  GameTables get t => ctx.tables;
  WavesTable get w => t.waves;
  double get dt => w.tickMs * secondsPerMillisecond;

  /// 전장 모양(탑다운) — 위치에 관한 것은 여기에 묻는다.
  BattleGeometry get geo => field.geometryOr(w);

  /// 공격 속도 배율 = 돛 + 지원 버프, 상한 `caps.attackSpeedMax` (설계서 4.8).
  double get attackSpeed => math.min(stats.attackSpeed + field.buffValue, t.shipParts.attackSpeedMax);

  /// 공격한 선원의 계열 (보스 패턴 판정용). 선원이 아니면 null.
  String? familyOf(String? crewId) =>
      crewId == null ? null : t.crews.crews.where((c) => c.id == crewId).firstOrNull?.family;

  /// 4.8 공식의 앞 네 항: 대포 × 선원 파워 × 배 등급 × [k](계열 배율·치명타 등).
  BigNum damageOf(Gun g, double k) =>
      stats.attack.times(g.power * stats.tierDamage * (1 + stats.bonus) * (g.legend?.powerScale ?? 1) * k);

  /// 적 이동·기절·배 접촉 피해 (규칙 3), 지원 버프 시간.
  void moveFoes() {
    final f = w.field;
    field.buffLeft -= dt;
    if (field.buffLeft <= 0) field.buffValue = 0;
    for (final e in field.living) {
      e.vulnerableTimer -= dt;
      if (e.vulnerableTimer <= 0) e.vulnerable = 0;
      if (e.stunned) {
        e.stunTimer -= dt;
        continue;
      }
      final speed = e.slowTimer > 0 ? e.speed * (1 - e.slow) : e.speed;
      e.slowTimer -= dt;
      if (e.slowTimer <= 0) e.slow = 0;
      // 다가가기(모양마다). 아직 닿지 않았으면 이번 틱은 공격하지 않는다.
      if (!geo.advance(e, speed, dt)) continue;
      e.contactTimer -= dt;
      if (e.contactTimer > 0) continue;
      e.contactTimer += f.contactIntervalSec;
      if (invincible) continue;
      // 보스는 정지 지점에서 원거리 공격 (렌더가 발사체를 그린다). 피해·간격은 접촉 공격과 같다.
      if (e.boss) ctx.emit(BossFired(ctx.tick, x: e.x, y: e.y));
      final hp = field.shipHp - e.attack;
      field.shipHp = hp.isNegative ? BigNum.zero : hp;
      final top = geo.viewShip != null; // 탑다운이면 피격 방향(때린 적 위치)을 싣는다
      ctx.emit(
        ShipDamaged(
          ctx.tick,
          amount: e.attack,
          hpRatio: (field.shipHp / field.shipHpMax).toDouble(),
          fromX: top ? e.x : null,
          fromY: top ? e.y : null,
        ),
      );
    }
    geo.settle(field, dt);
  }

  /// 슬롯마다 쿨타임을 돌리고, 준비됐고 맞힐 적이 있으면 쏜다 (규칙 5, 사다리 발사체 수).
  void fireGuns() {
    for (final g in field.guns) {
      g.cooldown -= dt * attackSpeed;
      if (g.cooldown > 0 && !zeroCooldown) continue;
      final a = g.attack;
      final shots = a.projectiles + (g.legend?.extraProjectiles ?? 0);
      final bonus = t.crews.byId(g.crewId).reachBonus;
      final volleys = [
        for (final v in geo.aimMany(a, shots, field.foes, ctx.rng, reachBonus: bonus))
          extendVolley(g, v, field.foes, w, geometry: geo),
      ];
      if (volleys.isEmpty) {
        if (g.cooldown < 0) g.cooldown = 0;
        continue;
      }
      g.cooldown = a.intervalSec;
      final crit = ctx.rng.nextDouble() < stats.critChance;
      if (crit) hitStop('crit');
      final base = damageOf(g, a.power * (crit ? stats.critMultiplier : 1) / shots);
      for (final v in volleys) {
        final m = geo.muzzle(v.x, v.y);
        ctx.emit(
          AttackFired(
            ctx.tick,
            crewId: g.crewId,
            family: g.family.id,
            targetIds: [for (final h in v.hits) h.foe.id],
            x: v.x,
            y: v.y,
            fromX: m?.x,
            fromY: m?.y,
            angle: m?.angle,
          ),
        );
        land(g, a, v, base, crit: crit);
        legendAfterHit(this, g, v, base, crit: crit);
      }
    }
  }

  /// 한 발의 결과: 피해(장판 계열은 절반 즉시 + 절반 장판), 밀어내기·기절.
  void land(Gun g, AttackDef a, Volley v, BigNum base, {bool crit = false}) {
    if (a.dotSec > 0) {
      strike(v, base.times(half), crit: crit, crewId: g.crewId);
      spawnZone(g, a, v.x, v.y, base.times(half));
    } else {
      strike(v, base, crit: crit, crewId: g.crewId);
    }
    control(v.hits.map((h) => h.foe), knockback: a.knockback, stunSec: a.stunSec);
  }

  /// 밀어내기·기절. 보스는 `bossControlFactor`만큼만 (설계서 4.10).
  void control(Iterable<Foe> foes, {double knockback = 0, double stunSec = 0}) {
    if (knockback <= 0 && stunSec <= 0) return;
    for (final e in foes) {
      if (!e.alive) continue;
      final k = e.boss ? t.skills.bossControlFactor : 1.0;
      geo.push(e, knockback * k);
      e.stunTimer = math.max(e.stunTimer, stunSec * k);
    }
  }

  /// 함성 게이지가 가득이면 선장의 궁극기: 보이는 화면(카메라 사각형) 전체 피해 + 계열별 추가 효과 (규칙 7, battle-m3 2).
  bool castUltimate() {
    final captain = field.captainId;
    if (rage < t.skills.rageMax || captain == null) return false;
    final gun = field.guns.firstWhere((g) => g.crewId == captain);
    final ult = gun.family.ultimate;
    final targets = [
      for (final e in field.foes)
        if (e.alive && geo.onScreen(e)) e,
    ];
    rage = 0;
    ctx.emit(UltimateCast(ctx.tick, crewId: captain, ultimateId: ult.id));
    hitStop('ultimate');
    if (ult.healRatio > 0) heal(ult.healRatio);
    if (targets.isEmpty) return true;
    strike(
      (x: geo.center.x, y: geo.center.y, hits: spread(targets, w)),
      damageOf(gun, t.skills.ultimateMultiplier),
      crewId: captain,
    );
    control(targets, knockback: ult.knockback, stunSec: ult.stunSec);
    return true;
  }

  /// 배 회복 (최대 HP 대비 [ratio]).
  void heal(double ratio) {
    final hp = field.shipHp + field.shipHpMax.times(ratio);
    field.shipHp = hp > field.shipHpMax ? field.shipHpMax : hp;
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
      if (n >= w.multiKillHitStopMinKills) hitStop('multiKill4');
    }
    field
      ..comboKills = 0
      ..comboGold = BigNum.zero;
  }

  /// 장판을 만든다: [total] 피해를 `dotSec` 동안 매 틱 나눠 준다.
  void spawnZone(Gun g, AttackDef a, double x, double y, BigNum total) {
    final ticks = math.max((a.dotSec / dt).round(), 1);
    field.zones.add(
      Zone(
        crewId: g.crewId,
        x: x,
        y: y,
        radius: geo.zoneRadius(a),
        ticksLeft: ticks,
        perTick: total.times(1 / ticks),
        excludeLayers: a.excludeLayers,
      ),
    );
    ctx.emit(ZoneSpawned(ctx.tick, crewId: g.crewId, x: x, y: y, radius: geo.zoneRadius(a), ticks: ticks));
  }

  /// 피해를 주고 처치를 처리한다. 2마리 이상이면 합산 숫자(AoeDamageSum).
  void strike(Volley v, BigNum base, {bool crit = false, String? crewId}) {
    var total = BigNum.zero;
    for (final h in v.hits) {
      final e = h.foe;
      if (!e.alive) continue;
      final g = guard(e, familyOf(crewId));
      if (g <= 0) continue; // 보호막: 피해 없음
      final vul = e.vulnerableTimer > 0 ? e.vulnerable : 0.0;
      final amount = base.times(h.factor * g * (1 + vul));
      total = total + amount;
      e.hp = e.hp - amount;
      ctx.emit(Damage(ctx.tick, targetId: e.id, amount: amount, crit: crit, crewId: crewId));
      if (!e.alive) _down(e);
    }
    if (v.hits.length > 1) ctx.emit(AoeDamageSum(ctx.tick, total: total, x: v.x, y: v.y));
  }

  /// 쓰러짐: 부활(한 번, 보상 없음) → 분열(작은 적) → 처치 보상.
  void _down(Foe e) {
    final def = e.def;
    if (def != null && def.role == 'revive' && !e.revived) {
      e
        ..revived = true
        ..hp = e.maxHp.times(def.reviveHpRatio);
      return;
    }
    final small = def?.splitInto;
    if (def != null && def.role == 'split' && small != null) {
      final sd = t.regions.enemies[small];
      for (var i = 0; i < def.splitCount; i++) {
        final at = geo.splitAt(e, i, def.splitCount);
        field.foes.add(
          Foe(
            id: field.nextId(),
            kind: small,
            layer: sd?.layer ?? e.layer,
            x: at.x,
            y: at.y,
            maxHp: e.maxHp.times(def.splitHpRatio),
            speed: sd?.speed ?? e.speed,
            attack: e.attack,
            gold: e.gold.times(def.splitHpRatio),
            def: sd,
          ),
        );
      }
    }
    _kill(e);
  }

  void _kill(Foe e) {
    final g = e.gold.times(stats.goldMultiplier);
    gold = gold + g;
    kills += 1;
    ctx.emit(Kill(ctx.tick, targetId: e.id, gold: g, x: e.x, y: e.y));
    rage = rage + t.skills.ragePerKill > t.skills.rageMax ? t.skills.rageMax : rage + t.skills.ragePerKill;
    field
      ..comboKills += 1
      ..comboGold = field.comboGold + g
      ..comboTimer = w.multiKillWindowSec;
  }

  /// 히트스톱 틱 = juice.hitStopMs[이유] / tickMs (올림). 엔진이 이번 틱의 가장 긴 것을 건다.
  void hitStop(String reason) {
    final ms = t.juice.hitStopMs[reason];
    if (ms == null) return;
    ctx.emit(HitStop(ctx.tick, ticks: (ms / w.tickMs).ceil(), reason: reason));
  }
}

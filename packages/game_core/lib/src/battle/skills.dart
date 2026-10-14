import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/units.dart';

/// 실제 시간 기준 쿨타임 하한을 지키는 슬롯 쿨타임 (공격 속도 배율 적용 전 단위).
/// 슬롯 쿨타임은 `dt × 공격 속도`씩 줄므로, 실제 시간 = 쿨타임 ÷ 속도 ≥ [minSec].
double skillCooldownFor(double cooldownSec, double attackSpeed, double minSec) =>
    math.max(cooldownSec, minSec * attackSpeed);

/// 자동 스킬과 장판 (docs/specs/battle-m3-skills.md 1·4).
extension SkillRound on Round {
  /// 슬롯마다 스킬 쿨타임을 돌리고, 준비됐으면 시전한다.
  void castSkills() {
    for (final g in field.guns) {
      g.skillCooldown -= dt * attackSpeed;
      if (g.skillCooldown > 0 && !zeroCooldown) continue;
      if (castSkill(g)) {
        g.skillCooldown = skillCooldownFor(g.skill.cooldownSec, attackSpeed, t.shipParts.skillCooldownMinSec);
      } else if (g.skillCooldown < 0) {
        g.skillCooldown = 0;
      }
    }
  }

  /// [g]의 스킬을 지금 쓴다. 맞힐 적이 없으면(배 대상 스킬 제외) 쓰지 않고 false.
  bool castSkill(Gun g) {
    final s = g.skill;
    final a = s.area;
    if (a.shape == 'ship') {
      heal(s.heal);
      field
        ..buffValue = math.max(field.buffValue, s.attackSpeedBuff)
        ..buffLeft = math.max(field.buffLeft, s.buffSec);
      ctx.emit(SkillCast(ctx.tick, crewId: g.crewId, skillId: s.id, x: w.field.shipX, y: w.field.shipY));
      return true;
    }
    final volleys = aimMany(a, a.count, field.foes, w, ctx.rng);
    if (volleys.isEmpty) return false;
    final base = damageOf(g, s.multiplier);
    if (_screenScope(g)) {
      // 전설 이상: 화면 안 전부, 대상당 비율로 예산 유지.
      final all = eligible(a, field.foes, w.field);
      final normal = volleys.fold(0, (n, v) => n + v.hits.length);
      final k = math.min(1, normal / all.length).toDouble();
      final v = (x: w.field.width * half, y: w.field.shipY, hits: [for (final e in all) (foe: e, factor: k)]);
      ctx.emit(SkillCast(ctx.tick, crewId: g.crewId, skillId: s.id, x: v.x, y: v.y, scope: 'screen'));
      land(g, a, v, base);
      return true;
    }
    for (final v in volleys) {
      ctx.emit(SkillCast(ctx.tick, crewId: g.crewId, skillId: s.id, x: v.x, y: v.y));
      land(g, a, v, base);
    }
    return true;
  }

  /// 장판마다 안의 적에게 한 틱 몫의 피해를 주고, 끝난 장판을 치운다.
  void tickZones() {
    for (final z in List.of(field.zones)) {
      final inside = [
        for (final e in field.foes)
          if (e.alive && !z.excludeLayers.contains(e.layer) && _within(e, z)) e,
      ];
      if (inside.isNotEmpty) strike((x: z.x, y: z.y, hits: spread(inside, w)), z.perTick, crewId: z.crewId);
      z.ticksLeft -= 1;
      if (z.ticksLeft <= 0) field.zones.remove(z);
    }
  }

  bool _screenScope(Gun g) =>
      t.skills.legendSkillScope == 'screen' && g.rarity >= t.rarities.rarities.indexWhere((r) => r.id == 'legend');

  static bool _within(Foe e, Zone z) {
    final dx = e.x - z.x;
    final dy = e.y - z.y;
    return dx * dx + dy * dy <= z.radius * z.radius;
  }
}

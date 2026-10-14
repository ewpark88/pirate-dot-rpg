import 'dart:math' as math;

import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// 전투가 쓰는 배·선원 수치.
///
/// 임시판: 테이블 공식을 직접 계산한다. 경제 레인이 강화 효과 함수를 공개하면
/// 그것으로 바꾼다 (docs/specs/battle-m1-core.md 결정 2, docs/contracts/requests/economy-stats.md).
class CombatStats {
  CombatStats._({
    required this.attack,
    required this.shipHp,
    required this.attackSpeed,
    required this.critChance,
    required this.critMultiplier,
    required this.goldMultiplier,
    required this.tierDamage,
    required this.slots,
  });

  factory CombatStats.of(GameState s, GameTables t) {
    final parts = t.shipParts;
    double linear(String id) => partValue(parts.byId(id), s.ship.level(id)).toDouble();
    final tier = t.shipTiers.tierAt(s.progress.stage);
    return CombatStats._(
      attack: partValue(parts.byId('cannon'), s.ship.level('cannon')),
      shipHp: partValue(parts.byId('hull'), s.ship.level('hull')),
      attackSpeed: math.min(linear('sail'), parts.attackSpeedMax),
      critChance: math.min(linear('crowsnest'), parts.critChanceMax),
      critMultiplier: parts.critMultiplier,
      goldMultiplier: linear('cargo'),
      tierDamage: 1 + tier.damageBonus,
      slots: tier.slots,
    );
  }

  /// 대포: 선원 전체 공격력 (설계서 4.2).
  final BigNum attack;
  final BigNum shipHp;

  /// 돛: 공격 속도 배율 (caps.attackSpeedMax까지).
  final double attackSpeed;
  final double critChance;
  final double critMultiplier;

  /// 화물칸: 골드 획득 배율.
  final double goldMultiplier;

  /// 배 등급 피해 배율 = 1 + damageBonus.
  final double tierDamage;

  /// 무기 슬롯 수.
  final int slots;
}

/// 배 부위 효과. exp: `base × growth^Lv`, linear: `base + growth × Lv`(maxLevel까지).
/// 마일스톤이 있으면 `milestoneEvery` 레벨마다 `milestoneMultiplier`배.
BigNum partValue(ShipPartDef p, int level) {
  final max = p.maxLevel;
  final lv = max != null && level > max ? max : level;
  var v = p.formula == 'exp' ? BigNum.powOf(p.growth, lv).times(p.base) : BigNum.from(p.base + p.growth * lv);
  final every = p.milestoneEvery;
  if (every != null && every > 0) v = v.times(math.pow(p.milestoneMultiplier, lv ~/ every));
  return v;
}

/// 레벨 → 등급 순번 (0 = common). 등급은 레벨 구간으로 정해진다 (rarities.json).
int rarityIndexAt(RarityTable r, int level) {
  final i = r.rarities.indexWhere((d) => level >= d.levelMin && level <= d.levelMax);
  return i < 0 ? r.rarities.length - 1 : i;
}

/// 선원 파워 = 레벨 배율 × 승급 배율 (설계서 4.8의 곱셈 항 두 개).
double crewPower(GameTables t, int level) {
  final g = t.growth;
  final levelMul = 1 + g.powerPerLevel * (level - 1);
  return levelMul * math.pow(g.promotionMultiplier, rarityIndexAt(t.rarities, level));
}

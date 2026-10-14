import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/crew_stats.dart';
import 'package:game_core/src/economy/ship_stats.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// 전투가 쓰는 배 수치. 강화 효과는 경제 레인의 [ShipStats], 배 등급은 shipTiers에서.
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
    final ship = ShipStats.of(t.shipParts, s.ship);
    final tier = t.shipTiers.tierAt(s.progress.stage);
    return CombatStats._(
      attack: ship.attack,
      shipHp: ship.maxHp,
      attackSpeed: ship.attackSpeed,
      critChance: ship.critChance,
      critMultiplier: ship.critMultiplier,
      goldMultiplier: ship.goldMultiplier,
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

/// 레벨 → 등급 순번 (0 = common).
int rarityIndexAt(RarityTable r, int level) => promotionCount(r, level);

/// 선원 파워 = 레벨 배율 × 승급 배율 (설계서 4.8의 곱셈 항 두 개).
double crewPower(GameTables t, int level) => crewPowerMultiplier(t.growth, t.rarities, level);

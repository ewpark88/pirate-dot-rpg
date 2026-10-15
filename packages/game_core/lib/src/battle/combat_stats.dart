import 'dart:math' as math;

import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/bonuses.dart';
import 'package:game_core/src/economy/crew_stats.dart';
import 'package:game_core/src/economy/formation.dart' show fleetSlots;
import 'package:game_core/src/economy/rebirth.dart' show rebirthBonus;
import 'package:game_core/src/economy/rebirth_shop.dart';
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
    this.bonus = 0,
  });

  /// [now]가 있으면 버프(순풍 골드, 함포 지원 피해)를 반영한다 (ads.json 보상 값).
  factory CombatStats.of(GameState s, GameTables t, {DateTime? now}) {
    bool active(DateTime? until) => now != null && until != null && until.isAfter(now);
    JsonReader reward(String id) => t.ads.placements.firstWhere((p) => p.id == id).reward;
    final ship = ShipStats.of(t.shipParts, s.ship);
    // 환생 조각 보너스: 골드의 % 합에 더한다 (설계서 4.5·4.8). 피해 % 합은 damageBonus(환생 + 보유 효과 + 도감).
    final rebirth = rebirthBonus(s, t);
    final tier = t.shipTiers.tierAt(s.progress.stage);
    return CombatStats._(
      attack: ship.attack,
      shipHp: ship.maxHp,
      attackSpeed: ship.attackSpeed,
      critChance: math.min(ship.critChance + critChanceBonus(s, t), t.shipParts.critChanceMax),
      critMultiplier: ship.critMultiplier + critDamageBonus(s, t),
      goldMultiplier:
          ship.goldMultiplier *
          (1 + rebirth) *
          (active(s.buffs.tailwindUntil) ? reward('tailwind').number('goldMultiplier') : 1),
      tierDamage: 1 + tier.damageBonus,
      bonus: damageBonus(s, t) + (active(s.buffs.bossSupportUntil) ? reward('bossSupport').number('damageBonus') : 0),
      slots: fleetSlots(s, t),
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

  /// 설계서 4.8 곱셈 마지막 항의 % 보너스 합 (함포 지원 등). 피해 × (1 + bonus).
  final double bonus;

  /// 무기 슬롯 수.
  final int slots;
}

/// 레벨 → 등급 순번 (0 = common).
int rarityIndexAt(RarityTable r, int level) => promotionCount(r, level);

/// 선원 파워 = 레벨 배율 × 승급 배율 (설계서 4.8의 곱셈 항 두 개).
double crewPower(GameTables t, int level) => crewPowerMultiplier(t.growth, t.rarities, level);

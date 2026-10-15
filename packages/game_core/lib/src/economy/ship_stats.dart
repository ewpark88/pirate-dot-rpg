import 'dart:math' as math;

import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_data/game_data.dart';
import 'package:meta/meta.dart';

// 배 부위 강화의 효과·비용 (설계서 4.2, 상한은 4.8). 전투 레인이 그대로 부른다.
// 모든 값은 ship_parts.json에서 읽는다.

/// 부위 [def]의 Lv[level] 효과 (마일스톤 도약 포함).
BigNum partEffect(ShipPartDef def, int level) {
  final raw = def.formula == 'exp'
      ? BigNum.powOf(def.growth, level).times(def.base)
      : BigNum.from(def.base + def.growth * level);
  return raw * _milestone(def, level);
}

/// 부위 [def]를 Lv[level]에서 Lv[level]+1로 올리는 비용.
BigNum partCost(ShipPartDef def, int level) => BigNum.powOf(def.costGrowth, level).times(def.costBase);

/// Lv[from]에서 [count]번 강화하는 비용 합 (등비수열 공식, 반복 없음): `costBase × g^from × (g^count − 1) / (g − 1)`.
BigNum partCostSum(ShipPartDef def, int from, int count) {
  if (count <= 0) return BigNum.zero;
  if (count == 1) return partCost(def, from); // 한 번은 partCost와 비트까지 같게(경계 판정)
  final g = def.costGrowth;
  return (BigNum.powOf(g, from + count) - BigNum.powOf(g, from)).times(def.costBase / (g - 1));
}

/// Lv[from]에서 [gold]로 살 수 있는 강화 수 (최대 레벨에서 멈춤). 로그 공식으로 구하고 경계만 ±1 확인한다.
int affordableLevels(ShipPartDef def, int from, BigNum gold) {
  final room = def.maxLevel == null ? null : def.maxLevel! - from;
  if ((room != null && room <= 0) || gold < partCost(def, from)) return 0;
  final g = def.costGrowth;
  // g^k ≤ 1 + gold × (g − 1) / (costBase × g^from)
  final x = gold.times((g - 1) / def.costBase) / BigNum.powOf(g, from);
  var k = ((x + BigNum.one).log10 / (math.log(g) / math.ln10)).floor();
  if (room != null && k > room) k = room;
  while (k > 0 && partCostSum(def, from, k) > gold) {
    k--;
  }
  while ((room == null || k < room) && partCostSum(def, from, k + 1) <= gold) {
    k++;
  }
  return k;
}

/// 부위 [def]의 Lv[level] 외형 단계 = `visualStages` 중 레벨 이하인 것의 수 (Lv0 = 0단계).
int partLookStage(ShipPartDef def, int level) {
  var n = 0;
  for (final v in def.visualStages) {
    if (v > level) break;
    n++;
  }
  return n;
}

/// 부위별 외형 단계 (렌더가 배 그림을 고른다). BattleView.shipLook과 같다.
Map<String, int> partLook(GameState s, GameTables t) => {
  for (final p in t.shipParts.parts) p.id: partLookStage(p, s.ship.level(p.id)),
};

/// 대포: 선원 전체 공격력.
BigNum shipAttack(ShipPartsTable t, int level) => partEffect(t.byId('cannon'), level);

/// 선체: 배 최대 HP.
BigNum shipMaxHp(ShipPartsTable t, int level) => partEffect(t.byId('hull'), level);

/// 돛: 공격 속도·스킬 쿨타임 배율 (상한 caps.attackSpeedMax).
double attackSpeedMultiplier(ShipPartsTable t, int level) =>
    math.min(partEffect(t.byId('sail'), level).toDouble(), t.attackSpeedMax);

/// 망루: 치명타 확률 0~1 (상한 caps.critChanceMax).
double critChance(ShipPartsTable t, int level) =>
    math.min(partEffect(t.byId('crowsnest'), level).toDouble(), t.critChanceMax);

/// 화물칸: 골드 획득 배율.
double goldMultiplier(ShipPartsTable t, int level) => partEffect(t.byId('cargo'), level).toDouble();

BigNum _milestone(ShipPartDef def, int level) {
  final every = def.milestoneEvery;
  if (every == null) return BigNum.one;
  return BigNum.powOf(def.milestoneMultiplier, level ~/ every);
}

// ShipStats 필드 이름이 위 함수를 가려서 클래스 밖에서 부른다.
double _critChanceOf(ShipPartsTable t, int level) => critChance(t, level);
double _goldMultiplierOf(ShipPartsTable t, int level) => goldMultiplier(t, level);

/// 배 강화가 전투에 주는 값 묶음.
@immutable
class ShipStats {
  const ShipStats({
    required this.attack,
    required this.maxHp,
    required this.attackSpeed,
    required this.critChance,
    required this.critMultiplier,
    required this.goldMultiplier,
    required this.skillCooldownMinSec,
  });

  factory ShipStats.of(ShipPartsTable t, ShipState ship) => ShipStats(
    attack: shipAttack(t, ship.level('cannon')),
    maxHp: shipMaxHp(t, ship.level('hull')),
    attackSpeed: attackSpeedMultiplier(t, ship.level('sail')),
    critChance: _critChanceOf(t, ship.level('crowsnest')),
    critMultiplier: t.critMultiplier,
    goldMultiplier: _goldMultiplierOf(t, ship.level('cargo')),
    skillCooldownMinSec: t.skillCooldownMinSec,
  );

  final BigNum attack;
  final BigNum maxHp;
  final double attackSpeed;
  final double critChance;
  final double critMultiplier;
  final double goldMultiplier;
  final double skillCooldownMinSec;
}

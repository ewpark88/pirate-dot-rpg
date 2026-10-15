import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/formation.dart';
import 'package:game_core/src/economy/offline.dart';
import 'package:game_core/src/economy/ship_stats.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';
import 'package:meta/meta.dart';

// 함대 전투력 (사용자 지시 2026-10-15): 출전 선원 + 배 강화 + 경제 % 보너스를 합친 숫자 하나.

@immutable
class FleetPower {
  const FleetPower({required this.dps, required this.power, required this.goldMultiplier});

  /// 초당 피해 기대치 (단일 대상, 치명타·공격 속도·배 등급·% 보너스 포함 — 오프라인 추정과 같은 식).
  final BigNum dps;

  /// 표시용 전투력 = (DPS × 배 최대 HP)^`meta.fleetPower.exponent`(0.5 = 기하 평균). 공격 쪽(대포·돛·망루·선원)과 버티기 쪽(선체)이 모두 올린다.
  final BigNum power;

  /// 화물칸 골드 배율 (전투력에는 없고 미리보기에서 따로 보여준다).
  final double goldMultiplier;
}

FleetPower fleetPower(GameState s, GameTables t) {
  final dps = fleetDps(s, t, activeFleet(s, t));
  final hp = shipMaxHp(t.shipParts, s.ship.level('hull'));
  return FleetPower(
    dps: dps,
    power: (dps * hp).pow(t.meta.raw.obj('fleetPower').number('exponent')),
    goldMultiplier: goldMultiplier(t.shipParts, s.ship.level('cargo')),
  );
}

/// 강화 버튼 미리보기: times번(또는 max면 골드로 가능한 만큼) 샀을 때. UpgradePart와 같은 계산.
@immutable
class UpgradePreview {
  const UpgradePreview({required this.levels, required this.cost, required this.before, required this.after});

  /// 실제로 살 수 있는 레벨 수 (골드·최대 레벨로 줄어든다). 0이면 버튼 비활성.
  final int levels;
  final BigNum cost;
  final FleetPower before;
  final FleetPower after;

  BigNum get powerBefore => before.power;
  BigNum get powerAfter => after.power;
  double get goldMultiplierBefore => before.goldMultiplier;
  double get goldMultiplierAfter => after.goldMultiplier;
}

UpgradePreview previewUpgrade(GameState s, GameTables t, String part, {int times = 1, bool max = false}) {
  final def = t.shipParts.byId(part);
  final from = s.ship.level(part);
  final can = affordableLevels(def, from, s.wallet.gold);
  final n = max || times > can ? can : times;
  final before = fleetPower(s, t);
  final after = n == 0 ? before : fleetPower(s.copyWith(ship: s.ship.withLevel(part, from + n)), t);
  return UpgradePreview(levels: n, cost: partCostSum(def, from, n), before: before, after: after);
}

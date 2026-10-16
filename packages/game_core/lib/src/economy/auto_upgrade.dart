import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/ads.dart' show autoUpgradeRemaining;
import 'package:game_core/src/economy/gold_cap.dart';
import 'package:game_core/src/economy/rebirth_shop.dart' show upgradeCostMultiplier;
import 'package:game_core/src/economy/ship_stats.dart';
import 'package:game_core/src/economy/upgrade.dart' show upgradePart;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

// 자동 강화 (사용자 결정 2026-10-16): 평소엔 수동 강화만. 보상형 광고(ads.json autoUpgrade)를 보면 10분 동안 자동.
// 버프 중 intervalSec마다 '살 수 있는 가장 싼 부위' 하나를 산다. 화물칸(금고)은 금고가 cargoBuyFull 이상 찼거나
// 다른 강화가 용량을 넘을 때만 — 금고를 비우게 하는 화물칸 규칙과 맞물린다.

JsonReader _reward(GameTables t) => t.ads.placements.firstWhere((p) => p.id == AdPlacement.autoUpgrade.name).reward;

/// 지금 자동으로 살 부위 (없으면 null).
String? autoUpgradePick(GameState s, GameTables t) {
  final mult = upgradeCostMultiplier(s, t);
  final cap = goldCapacity(s, t);
  String? cheapestOf({required bool withCargo}) {
    String? best;
    BigNum? cost;
    for (final p in t.shipParts.parts) {
      if (!withCargo && p.id == 'cargo') continue;
      final lv = s.ship.level(p.id);
      if (p.maxLevel != null && lv >= p.maxLevel!) continue;
      final c = partCost(p, lv).times(mult);
      if (cost == null || c < cost) (best, cost) = (p.id, c);
    }
    return best;
  }

  final other = cheapestOf(withCargo: false);
  final otherCost = other == null ? null : partCost(t.shipParts.byId(other), s.ship.level(other)).times(mult);
  final needCargo =
      s.wallet.gold >= cap.times(_reward(t).number('cargoBuyFull')) || (otherCost != null && otherCost > cap);
  final pick = needCargo ? cheapestOf(withCargo: true) : other;
  if (pick == null) return null;
  final cost = partCost(t.shipParts.byId(pick), s.ship.level(pick)).times(mult);
  return s.wallet.gold < cost ? null : pick;
}

/// EconomySystem.update에서 매 틱: 버프 중이고 intervalSec 틱마다 하나 산다.
GameState autoUpgradeStep(GameState s, SystemContext ctx) {
  final t = ctx.tables;
  if (autoUpgradeRemaining(s, ctx.clock.now()) == Duration.zero) return s;
  final every = (_reward(t).number('intervalSec') / (t.waves.tickMs * secondsPerMillisecond)).round();
  if (every > 0 && ctx.tick % every != 0) return s;
  final pick = autoUpgradePick(s, t);
  return pick == null ? s : upgradePart(s, UpgradePart(pick), ctx);
}

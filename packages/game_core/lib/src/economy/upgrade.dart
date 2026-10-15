import 'package:game_core/src/economy/daily.dart';
import 'package:game_core/src/economy/ship_stats.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';

/// 배 부위 강화 (설계서 4.2). [UpgradePart.times]번까지, 골드가 되는 만큼만 산다.
/// 하나도 못 사면 상태 그대로, 이벤트 없음.
GameState upgradePart(GameState state, UpgradePart command, SystemContext ctx) {
  final defs = ctx.tables.shipParts.parts.where((p) => p.id == command.part);
  if (defs.isEmpty) return state;
  final def = defs.first;

  final start = state.ship.level(def.id);
  final can = affordableLevels(def, start, state.wallet.gold);
  final n = command.max || command.times > can ? can : command.times;
  if (n <= 0) return state;
  // 비용은 공식 합 한 번 (일괄·최대 강화 성능). 이벤트는 레벨마다 (스펙 economy-m1 기준 1).
  final gold = state.wallet.gold - partCostSum(def, start, n);
  final level = start + n;
  final every = def.milestoneEvery;
  for (var l = start + 1; l <= level; l++) {
    ctx.emit(PartUpgraded(ctx.tick, part: def.id, level: l));
    if (every != null && l % every == 0) ctx.emit(PartMilestone(ctx.tick, part: def.id, level: l));
  }
  final lookBefore = partLookStage(def, start);
  final look = partLookStage(def, level);
  if (look > lookBefore) ctx.emit(ShipLookChanged(ctx.tick, part: def.id, stage: look));

  ctx.emit(SaveRequested(ctx.tick, reason: command.type));
  final s = state.copyWith(
    wallet: state.wallet.copyWith(gold: gold),
    ship: state.ship.withLevel(def.id, level),
  );
  return addQuestProgress(s, ctx.tables, 'upgrade', level - start);
}

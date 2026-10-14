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

  var gold = state.wallet.gold;
  var level = state.ship.level(def.id);
  final start = level;
  for (var i = 0; i < command.times; i++) {
    final max = def.maxLevel;
    if (max != null && level >= max) break;
    final cost = partCost(def, level);
    if (gold < cost) break;
    gold = gold - cost;
    level++;
    ctx.emit(PartUpgraded(ctx.tick, part: def.id, level: level));
    final every = def.milestoneEvery;
    if (every != null && level % every == 0) ctx.emit(PartMilestone(ctx.tick, part: def.id, level: level));
  }
  if (level == start) return state;

  ctx.emit(SaveRequested(ctx.tick, reason: command.type));
  final s = state.copyWith(
    wallet: state.wallet.copyWith(gold: gold),
    ship: state.ship.withLevel(def.id, level),
  );
  return addQuestProgress(s, ctx.tables, 'upgrade', level - start);
}

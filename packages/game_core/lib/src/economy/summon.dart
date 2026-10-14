import 'package:game_core/src/economy/cards.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 소환 카드 등급 한 번 굴리기. [pity]면 `pity.minRarity` 이상끼리 확률 비례로 굴린다.
String rollSummonRarity(RarityTable t, Rng rng, {required bool pity}) {
  final minIndex = pity ? rarityOrder.indexOf(t.pityMinRarity) : 0;
  final pool = [
    for (final r in t.rarities)
      if (r.summonRate > 0 && t.rarities.indexOf(r) >= minIndex) r,
  ];
  final total = pool.fold<double>(0, (s, r) => s + r.summonRate);
  var u = rng.nextDouble() * total;
  for (final r in pool) {
    u -= r.summonRate;
    if (u < 0) return r.id;
  }
  return pool.last.id;
}

/// 선원 소환 (설계서 4.3). 젬이 모자라면 상태 그대로, 이벤트 없음.
/// 선원은 40명 균등, 등급은 rarities.json 확률 + 천장.
GameState summon(GameState state, Summon command, SystemContext ctx) {
  final t = ctx.tables;
  if (!canSummon(state, t, command.count)) return state;

  final minIndex = rarityOrder.indexOf(t.rarities.pityMinRarity);
  var s = state.copyWith(wallet: state.wallet.copyWith(gems: state.wallet.gems - summonCost(t.meta, command.count)));
  final results = <({String crewId, String rarity})>[];
  for (var i = 0; i < command.count; i++) {
    final rarity = rollSummonRarity(t.rarities, ctx.rng, pity: s.pityCount + 1 >= t.rarities.pityCount);
    final crewId = t.crews.crews[ctx.rng.nextInt(t.crews.crews.length)].id;
    final pityCount = rarityOrder.indexOf(rarity) >= minIndex ? 0 : s.pityCount + 1;
    s = receiveCard(s, t, crewId, rarity).copyWith(pityCount: pityCount);
    results.add((crewId: crewId, rarity: rarity));
  }
  ctx
    ..emit(CrewSummoned(ctx.tick, results: results))
    ..emit(SaveRequested(ctx.tick, reason: command.type));
  return s;
}

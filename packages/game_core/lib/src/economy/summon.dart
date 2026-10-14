import 'package:game_core/src/economy/cards.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_core/src/ports/ports.dart';
import 'package:game_data/game_data.dart';

/// 소환 카드 등급 한 번 굴리기. [pity]면 [minRarity](기본 `pity.minRarity`) 이상끼리 확률 비례로 굴린다.
String rollSummonRarity(RarityTable t, Rng rng, {required bool pity, String? minRarity}) {
  final minIndex = pity ? rarityOrder.indexOf(minRarity ?? t.pityMinRarity) : 0;
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

  final free = isFreeFirstTen(state, t, command.count);
  final guarantee = rarityOrder.indexOf(t.meta.raw.obj('tutorial').str('firstTenGuarantee'));
  final minIndex = rarityOrder.indexOf(t.rarities.pityMinRarity);
  var s = state.copyWith(
    wallet: state.wallet.copyWith(gems: state.wallet.gems - summonCostFor(state, t, command.count)),
    summonsTotal: state.summonsTotal + command.count,
  );
  final results = <({String crewId, String rarity})>[];
  final shown = <SummonResult>[];
  var guaranteed = false;
  for (var i = 0; i < command.count; i++) {
    // 무료 첫 10연: 마지막 장까지 확정 등급이 안 나왔으면 마지막 장을 확정 등급 이상으로 굴린다.
    final forceTutorial = free && !guaranteed && i == command.count - 1;
    final pity = s.pityCount + 1 >= t.rarities.pityCount;
    final rarity = forceTutorial
        ? rollSummonRarity(t.rarities, ctx.rng, pity: true, minRarity: rarityOrder[guarantee])
        : rollSummonRarity(t.rarities, ctx.rng, pity: pity);
    if (rarityOrder.indexOf(rarity) >= guarantee) guaranteed = true;
    final crewId = t.crews.crews[ctx.rng.nextInt(t.crews.crews.length)].id;
    final pityCount = rarityOrder.indexOf(rarity) >= minIndex ? 0 : s.pityCount + 1;
    shown.add(SummonResult(crewId: crewId, rarity: rarity, isNew: !s.crews.containsKey(crewId)));
    s = receiveCard(s, t, crewId, rarity).copyWith(pityCount: pityCount);
    results.add((crewId: crewId, rarity: rarity));
  }
  ctx
    ..emit(CrewSummoned(ctx.tick, results: results))
    ..emit(SaveRequested(ctx.tick, reason: command.type));
  return s.copyWith(lastSummon: shown);
}

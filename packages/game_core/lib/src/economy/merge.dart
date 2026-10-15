import 'package:game_core/src/economy/cards.dart';
import 'package:game_core/src/economy/crew_stats.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_data/game_data.dart';

/// 선원 하나의 적립 경험치를 레벨로 바꾼다. 등급 마지막 레벨(승급 문)에서 멈춘다.
CrewState mergeCrew(CrewState crew, GameTables t) {
  var c = crew;
  while (canLevelUp(c, t)) {
    c = c.copyWith(level: c.level + 1, exp: c.exp - t.growth.expToNext[rarityOfLevel(t.rarities, c.level).id]!);
  }
  return c;
}

/// 일괄 합치기 (설계서 4.3.1). 바뀐 선원이 없으면 상태 그대로, 이벤트 없음.
GameState mergeAllCards(GameState state, MergeAllCards command, SystemContext ctx) {
  final crews = {for (final e in state.crews.entries) e.key: mergeCrew(e.value, ctx.tables)};
  final changed = crews.entries.any((e) => e.value.level != state.crews[e.key]!.level);
  if (!changed) return state;
  ctx.emit(SaveRequested(ctx.tick, reason: command.type));
  return state.copyWith(crews: crews);
}

/// 해적 한 명 승급 (설계서 4.3.1). 조건이 모자라면 상태 그대로, 이벤트 없음.
GameState promoteCrew(GameState state, PromoteCrew command, SystemContext ctx) {
  final t = ctx.tables;
  if (!canPromote(state, t, command.crewId)) return state;
  final crew = state.crews[command.crewId]!;
  final p = nextPromotion(t, crew.level)!;
  final to = t.rarities.byId(p.to);
  ctx
    ..emit(CrewPromoted(ctx.tick, crewId: command.crewId, rarity: to.id))
    ..emit(SaveRequested(ctx.tick, reason: command.type));
  return state.copyWith(
    wallet: state.wallet.copyWith(gold: state.wallet.gold - promotionGold(t, p, state.progress.stage)),
    tokens: state.tokens - p.tokens,
    crews: {
      ...state.crews,
      command.crewId: crew.copyWith(level: to.levelMin, cards: crew.cards - p.cards),
    },
  );
}

import 'package:game_core/src/battle/spawner.dart' show stageCurve;
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/crew_stats.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_data/game_data.dart';

// 소환 비용·승급 판정·카드 받기 (설계서 4.3.1, 4.3.3). UI가 버튼 상태에 그대로 쓴다.

/// [count]회 소환에 드는 젬.
int summonCost(MetaTable meta, int count) => meta.summonCostGems * count;

/// [count]회 소환할 수 있는가.
bool canSummon(GameState state, GameTables t, int count) => count > 0 && state.wallet.gems >= summonCost(t.meta, count);

/// Lv[level] 선원의 다음 승급. 신화면 null.
PromotionDef? nextPromotion(GameTables t, int level) {
  final from = rarityOfLevel(t.rarities, level).id;
  final found = t.growth.promotions.where((p) => p.from == from);
  return found.isEmpty ? null : found.first;
}

/// 승급 골드 = [stage] 일반 몬스터 처치 골드(화물칸 배율 전) × [PromotionDef.goldKills].
BigNum promotionGold(GameTables t, PromotionDef p, int stage) =>
    stageCurve(t.waves.goldBase, t.waves.goldGrowth, stage).times(p.goldKills);

/// 승급 버튼 상태. [ok]가 아니면 무엇이 모자란지.
enum PromoteStatus { ok, notOwned, maxRarity, level, cards, gold, tokens }

PromoteStatus promoteStatus(GameState state, GameTables t, String crewId) {
  final crew = state.crews[crewId];
  if (crew == null) return PromoteStatus.notOwned;
  final p = nextPromotion(t, crew.level);
  if (p == null) return PromoteStatus.maxRarity;
  if (crew.level < p.level) return PromoteStatus.level;
  if (crew.cards < p.cards) return PromoteStatus.cards;
  if (state.wallet.gold < promotionGold(t, p, state.progress.stage)) return PromoteStatus.gold;
  if (state.tokens < p.tokens) return PromoteStatus.tokens;
  return PromoteStatus.ok;
}

bool canPromote(GameState state, GameTables t, String crewId) => promoteStatus(state, t, crewId) == PromoteStatus.ok;

/// 카드 한 장 받기 (소환·보스·오프라인 공통, 스펙 결정 ①).
/// - 처음 보는 선원: 카드 등급 첫 레벨로 보유 + 도감
/// - 카드 등급이 현재 등급보다 높음: 그 등급 첫 레벨로 점프(경험치 0)
/// - 신화 최고 레벨: 증표
/// - 그 외: 카드 등급 경험치 적립 + 승급용 장수 1
GameState receiveCard(GameState state, GameTables t, String crewId, String rarity) {
  final card = t.rarities.byId(rarity);
  final crew = state.crews[crewId];
  if (crew == null) {
    return state.copyWith(
      crews: {
        ...state.crews,
        crewId: CrewState(level: card.levelMin),
      },
      collection: {...state.collection, crewId},
    );
  }
  final current = rarityOfLevel(t.rarities, crew.level);
  if (t.rarities.rarities.indexOf(card) > t.rarities.rarities.indexOf(current)) {
    return state.copyWith(
      crews: {
        ...state.crews,
        crewId: crew.copyWith(level: card.levelMin, exp: 0),
      },
    );
  }
  if (crew.level >= t.growth.maxLevel) return state.copyWith(tokens: state.tokens + t.growth.tokenPerSurplusCard);
  return state.copyWith(
    crews: {
      ...state.crews,
      crewId: crew.copyWith(exp: crew.exp + (t.growth.cardExp[rarity] ?? 0), cards: crew.cards + 1),
    },
  );
}

import 'dart:math' as math;

import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/cards.dart' show canLevelUp, nextPromotion;
import 'package:game_core/src/economy/crew_stats.dart';
import 'package:game_core/src/economy/merge.dart' show mergeCrew;
import 'package:game_core/src/economy/offline.dart' show fleetDps;
import 'package:game_core/src/economy/rebirth_shop.dart' show crewMaxLevel;
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_data/game_data.dart';

/// 선원 상세 '레벨을 올리는 이유'(사용자 피드백 #12 — '레벨을 올리는 이유가 뭐야? 표현도 빈약해'). UI는 이 값만 쓴다.
/// - `levelGain`: 한 레벨 오르면 공격력이 몇 배 더(0.08 = +8%). 승급 문 앞·최대 레벨이면 0.
/// - `dpsNow` → `dpsNext`: 이 선원 혼자의 초당 피해, 다음 레벨이면.
/// - `mergeLevels`: 지금 합치면(MergeAllCards) 오르는 레벨 수. 0이면 합칠 것 없음.
/// - `cardsToLevel`: 다음 레벨까지 일반 카드 장수(카드 경험치 = growth.cardExp, 높은 등급 카드는 더 적게). 합칠 게 있거나 문 앞이면 0.
/// - `levelsToPromote`: 승급 레벨까지 남은 레벨(문 앞이면 0, 신화면 null). `promoteGain`: 승급하면 공격력 몇 배 더.
typedef CrewGrowthView = ({
  double levelGain,
  BigNum dpsNow,
  BigNum dpsNext,
  int mergeLevels,
  int cardsToLevel,
  int? levelsToPromote,
  double promoteGain,
});

/// 지금 합치면 [crew]가 몇 레벨 오르는가(카드 칸 배지용 — 매 틱 불려도 가볍게, DPS 계산 없음).
int mergeGain(CrewState crew, GameTables t, {int? maxLevel}) =>
    canLevelUp(crew, t, maxLevel: maxLevel) ? mergeCrew(crew, t, maxLevel: maxLevel).level - crew.level : 0;

/// [crewId]가 없으면 null.
CrewGrowthView? crewGrowth(GameState s, GameTables t, String crewId) {
  final crew = s.crews[crewId];
  if (crew == null) return null;
  final max = crewMaxLevel(s, t);
  final g = t.growth;
  final rarity = rarityOfLevel(t.rarities, crew.level);
  final last = identical(rarity, t.rarities.rarities.last);
  final cap = last ? max : rarity.levelMax;
  final open = crew.level < cap;
  final now = crewPowerMultiplier(g, t.rarities, crew.level);
  final levelGain = open ? crewPowerMultiplier(g, t.rarities, crew.level + 1) / now - 1 : 0.0;
  final dps = fleetDps(s, t, [crewId]);
  final need = g.expToNext[rarity.id] ?? 0;
  final perCard = g.cardExp[t.rarities.rarities.first.id] ?? 1;
  final merged = mergeGain(crew, t, maxLevel: max);
  final p = nextPromotion(t, crew.level);
  return (
    levelGain: levelGain,
    dpsNow: dps,
    dpsNext: dps.times(1 + levelGain),
    mergeLevels: merged,
    cardsToLevel: !open || canLevelUp(crew, t, maxLevel: max) || need <= 0
        ? 0
        : ((need - crew.exp) / (perCard <= 0 ? 1 : perCard)).ceil(),
    levelsToPromote: p == null ? null : math.max(0, p.level - crew.level),
    promoteGain: p == null ? 0 : g.promotionMultiplier - 1,
  );
}

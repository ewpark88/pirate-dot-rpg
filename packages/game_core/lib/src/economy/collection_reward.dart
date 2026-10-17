import 'package:game_core/src/economy/summon.dart' show summonCards;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

// 도감 수집 보상 (S1 2026-10-17, S4 '수집의 재미'): 보유 선원 수(collection, 한 번 얻으면 줄지 않음)가 칸에 닿으면 받기 버튼.
// 칸·보상은 meta.collectionRewards [{at, gems?, summons?}]. 받은 칸은 progress.collectionClaimed(환생해도 유지).

/// 수집 보상 칸 하나 (UI 진행 막대·받기 버튼).
typedef CollectionRewardView = ({int at, int gems, int summons, bool reached, bool claimed});

/// 모든 칸 — 표 순서(at 오름차순).
List<CollectionRewardView> collectionRewards(GameState s, GameTables t) {
  final have = s.collection.length;
  return [
    for (final r in t.meta.raw.objs('collectionRewards'))
      (
        at: r.integer('at'),
        gems: r.intOrNull('gems') ?? 0,
        summons: r.intOrNull('summons') ?? 0,
        reached: have >= r.integer('at'),
        claimed: s.progress.collectionClaimed.contains(r.integer('at')),
      ),
  ];
}

/// 받을 수 있는 칸 수(UI 배지).
int collectionRewardsReady(GameState s, GameTables t) =>
    collectionRewards(s, t).where((r) => r.reached && !r.claimed).length;

/// ClaimCollectionReward: 닿았고 안 받은 칸이면 젬 + 무료 소환. 아니면 상태 그대로(이벤트 없음).
GameState claimCollectionReward(GameState s, ClaimCollectionReward c, SystemContext ctx) {
  final r = collectionRewards(s, ctx.tables).where((x) => x.at == c.at).firstOrNull;
  if (r == null || !r.reached || r.claimed) return s;
  var next = s.copyWith(
    wallet: s.wallet.copyWith(gems: s.wallet.gems + r.gems),
    progress: s.progress.copyWith(collectionClaimed: [...s.progress.collectionClaimed, r.at]),
  );
  ctx.emit(CollectionRewardClaimed(ctx.tick, at: r.at, gems: r.gems, summons: r.summons));
  if (r.summons > 0) next = summonCards(next, ctx, r.summons, reason: c.type);
  ctx.emit(SaveRequested(ctx.tick, reason: c.type));
  return next;
}

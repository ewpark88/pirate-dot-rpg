import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 도감 수집 보상 (S1 2026-10-17, S4 '수집의 재미'): 5·10·20·30·40명 칸, 받기 한 번, 환생해도 다시 안 준다, 세이브 선택 키.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;

  GameState owning(EconomyHarness h, int n) {
    final ids = [for (final c in t.crews.crews.take(n)) c.id];
    return h.newGame().copyWith(crews: {for (final id in ids) id: const CrewState()}, collection: ids.toSet());
  }

  test('칸: 5·10·20·30·40명, 닿은 칸만 reached, 받을 수 있는 수', () {
    final h = EconomyHarness();
    final v = collectionRewards(owning(h, 12), t);
    expect(v.map((r) => r.at), [5, 10, 20, 30, 40]);
    expect(v.map((r) => r.reached), [true, true, false, false, false]);
    expect(collectionRewardsReady(owning(h, 12), t), 2);
  });

  test('받기: 젬 +, 소환 칸은 무료 소환(CrewSummoned), 두 번째는 그대로 · 안 닿은 칸은 그대로', () {
    final h = EconomyHarness();
    final s0 = owning(h, 12);
    final s1 = sys.handle(s0, const ClaimCollectionReward(5), h.ctx)!;
    expect(s1.wallet.gems, s0.wallet.gems + 30);
    expect(h.of<CollectionRewardClaimed>().single.at, 5);
    expect(sys.handle(s1, const ClaimCollectionReward(5), h.ctx), s1);
    final s2 = sys.handle(s1, const ClaimCollectionReward(10), h.ctx)!;
    expect(h.of<CrewSummoned>().single.results, hasLength(1));
    expect(s2.summonsTotal, s1.summonsTotal + 1);
    expect(sys.handle(s2, const ClaimCollectionReward(20), h.ctx), s2, reason: '12명 — 20 칸은 아직');
    expect(collectionRewardsReady(s2, t), 0);
  });

  test('세이브: 받은 칸은 선택 키로 왕복, 비면 본문에 없다 · 환생해도 유지 · 명령 JSON 왕복', () {
    final h = EconomyHarness();
    final s = sys.handle(owning(h, 6), const ClaimCollectionReward(5), h.ctx)!;
    expect(SaveCodec.decode(SaveCodec.encode(s)).progress.collectionClaimed, [5]);
    expect(const Progress().toJson().containsKey('collectionClaimed'), isFalse);
    final reborn = sys.handle(
      s.copyWith(progress: s.progress.copyWith(stage: 50, bestStage: 50)),
      const Rebirth(),
      h.ctx,
    )!;
    expect(reborn.progress.collectionClaimed, [5]);
    expect(Command.fromJson(const ClaimCollectionReward(5).toJson()).toJson(), const ClaimCollectionReward(5).toJson());
    const e = CollectionRewardClaimed(3, at: 10, summons: 1);
    expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson());
  });
}

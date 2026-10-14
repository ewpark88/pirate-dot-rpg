import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// UI가 승급 버튼(빨간 점)에 쓰는 판정 함수.
void main() {
  final t = EconomyHarness.tables;
  final h = EconomyHarness();
  final w = t.waves;

  GameState withOcto(CrewState c, {num gold = 0, int tokens = 0, int stage = 1}) => h
      .newGame(gold: BigNum.from(gold))
      .copyWith(
        crews: {'octo': c},
        tokens: tokens,
        progress: Progress(stage: stage, bestStage: stage),
      );

  test('다음 승급: 일반 → 희귀 … 신화는 없음', () {
    expect(nextPromotion(t, 1)!.to, 'rare');
    expect(nextPromotion(t, 15)!.to, 'rare');
    expect(nextPromotion(t, 16)!.to, 'hero');
    expect(nextPromotion(t, 60)!.to, 'mythic');
    expect(nextPromotion(t, 61), isNull);
  });

  test('승급 골드 = 그 스테이지 일반 몬스터 처치 골드 × goldKills', () {
    final p = nextPromotion(t, 15)!;
    final kill = BigNum.powOf(w.goldGrowth, 9).times(w.goldBase);
    expect(promotionGold(t, p, 10).closeTo(kill.times(100)), isTrue);
  });

  test('승급 판정 사유', () {
    final gold = promotionGold(t, nextPromotion(t, 15)!, 1);
    expect(promoteStatus(h.newGame(), t, 'octo'), PromoteStatus.notOwned);
    expect(promoteStatus(withOcto(const CrewState(level: 14, cards: 9), gold: 1e30), t, 'octo'), PromoteStatus.level);
    expect(promoteStatus(withOcto(const CrewState(level: 15, cards: 2), gold: 1e30), t, 'octo'), PromoteStatus.cards);
    expect(
      promoteStatus(withOcto(const CrewState(level: 15, cards: 3), gold: gold.toDouble() * 0.5), t, 'octo'),
      PromoteStatus.gold,
    );
    expect(promoteStatus(withOcto(const CrewState(level: 15, cards: 3), gold: 1e30), t, 'octo'), PromoteStatus.ok);
    expect(canPromote(withOcto(const CrewState(level: 15, cards: 3), gold: 1e30), t, 'octo'), isTrue);
    expect(
      promoteStatus(withOcto(const CrewState(level: 60, cards: 99), gold: 1e60, tokens: 49), t, 'octo'),
      PromoteStatus.tokens,
    );
    expect(promoteStatus(withOcto(const CrewState(level: 75), gold: 1e60), t, 'octo'), PromoteStatus.maxRarity);
  });
}

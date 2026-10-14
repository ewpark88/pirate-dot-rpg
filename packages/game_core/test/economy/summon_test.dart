import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_core/src/economy/summon.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 스펙 economy-m1 수용 기준 5~8, 11 (소환·천장·카드 받기).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  test('소환 비용 = summonCostGems × 횟수', () {
    expect(summonCost(t.meta, 1), t.meta.summonCostGems);
    expect(summonCost(t.meta, 10), t.meta.summonCostGems * 10);
    final s = h.newGame(gems: t.meta.summonCostGems * 10);
    expect(canSummon(s, t, 10), isTrue);
    expect(canSummon(s, t, 11), isFalse);
    expect(canSummon(s, t, 0), isFalse);
  });

  test('기준 5: 10연 소환 — 카드 10장, 젬 0, CrewSummoned 결과 10개', () {
    // 첫 10연 무료는 preview_free_summon_test에서 — 여기는 유료 10연.
    final s0 = h.newGame(gems: t.meta.summonCostGems * 10).copyWith(summonsTotal: 10);
    final s = sys.handle(s0, const Summon(count: 10), h.ctx)!;
    expect(s.wallet.gems, 0);
    final results = h.of<CrewSummoned>().single.results;
    expect(results, hasLength(10));
    for (final r in results) {
      expect(s.crews.containsKey(r.crewId), isTrue);
      expect(s.collection, contains(r.crewId));
    }
    expect(h.of<SaveRequested>(), hasLength(1));
  });

  test('젬이 모자라면 상태·이벤트 변화 없음', () {
    final s0 = h.newGame(gems: t.meta.summonCostGems - 1);
    final s = sys.handle(s0, const Summon(), h.ctx)!;
    expect(s.wallet.gems, t.meta.summonCostGems - 1);
    expect(h.events, isEmpty);
  });

  test('기준 6: pityCount 49이면 다음 소환은 영웅 이상이고 천장이 0으로', () {
    const heroIndex = 2;
    for (var seed = 1; seed <= 300; seed++) {
      final hs = EconomyHarness(seed: seed);
      final s0 = hs.newGame(gems: t.meta.summonCostGems).copyWith(pityCount: t.rarities.pityCount - 1);
      final s = sys.handle(s0, const Summon(), hs.ctx)!;
      final r = hs.of<CrewSummoned>().single.results.single;
      expect(rarityOrder.indexOf(r.rarity), greaterThanOrEqualTo(heroIndex), reason: 'seed $seed');
      expect(s.pityCount, 0);
    }
  });

  test('천장: 영웅 미만이 50번 연속 나오는 일은 없다 (5,000회)', () {
    var s = h.newGame(gems: t.meta.summonCostGems * 5000);
    for (var i = 0; i < 500; i++) {
      s = sys.handle(s, const Summon(count: 10), h.ctx)!;
    }
    var run = 0;
    var maxRun = 0;
    for (final e in h.of<CrewSummoned>()) {
      for (final r in e.results) {
        run = rarityOrder.indexOf(r.rarity) >= rarityOrder.indexOf(t.rarities.pityMinRarity) ? 0 : run + 1;
        if (run > maxRun) maxRun = run;
      }
    }
    expect(maxRun, lessThan(t.rarities.pityCount));
    expect(s.pityCount, run);
  });

  test('기준 7 (설계서 9.3): 100만 회 등급 비율이 표시 확률 ±0.2%p (천장 제외)', () {
    const n = 1000000;
    final counts = <String, int>{};
    final rng = XorShiftRng(2026);
    for (var i = 0; i < n; i++) {
      final r = rollSummonRarity(t.rarities, rng, pity: false);
      counts[r] = (counts[r] ?? 0) + 1;
    }
    for (final r in t.rarities.rarities) {
      expect((counts[r.id] ?? 0) / n, closeTo(r.summonRate, 0.002), reason: r.id);
    }
  });

  group('카드 받기', () {
    test('처음 보는 선원은 카드 등급의 첫 레벨로 보유 + 도감', () {
      final s = receiveCard(h.newGame(), t, 'octo', 'rare');
      expect(s.crews['octo']!.level, t.rarities.byId('rare').levelMin);
      expect(s.collection, contains('octo'));
    });

    test('같은 등급 카드는 경험치(cardExp) 적립 + 승급용 장수 1', () {
      final s0 = h.newGame().copyWith(crews: {'octo': const CrewState(level: 5)});
      final s = receiveCard(receiveCard(s0, t, 'octo', 'common'), t, 'octo', 'common');
      expect(s.crews['octo']!.exp, t.growth.cardExp['common']! * 2);
      expect(s.crews['octo']!.cards, 2);
      expect(s.crews['octo']!.level, 5);
    });

    test('낮은 등급 카드도 그 등급의 경험치로 적립', () {
      final s0 = h.newGame().copyWith(crews: {'octo': const CrewState(level: 20)});
      final s = receiveCard(s0, t, 'octo', 'common');
      expect(s.crews['octo']!.exp, t.growth.cardExp['common']);
      expect(s.crews['octo']!.cards, 1);
    });

    test('기준 8: 일반 Lv5 선원이 전설 카드를 받으면 Lv46으로 점프', () {
      final s0 = h.newGame().copyWith(crews: {'octo': const CrewState(level: 5, exp: 3, cards: 2)});
      final c = receiveCard(s0, t, 'octo', 'legend').crews['octo']!;
      expect(c.level, t.rarities.byId('legend').levelMin);
      expect(c.exp, 0);
      expect(c.cards, 2);
    });

    test('기준 11: 신화 Lv75 선원의 카드는 증표가 된다', () {
      final s0 = h.newGame().copyWith(crews: {'octo': CrewState(level: t.growth.maxLevel)});
      final s = receiveCard(s0, t, 'octo', 'hero');
      expect(s.tokens, t.growth.tokenPerSurplusCard);
      expect(s.crews['octo']!.cards, 0);
      expect(s.crews['octo']!.exp, 0);
    });
  });
}

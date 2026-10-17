import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 첫 전설 유예(BALANCE.md '첫 전설 최소 1일', smoke에서 14분 사례): 첫 회차 최고 스테이지 untilStage 전에는 전설 이상 카드가 영웅으로.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  final until = t.meta.raw.obj('firstLegend').integer('untilStage');

  int legends(Iterable<({String crewId, String rarity})> rs) =>
      rs.where((r) => r.rarity == 'legend' || r.rarity == 'mythic').length;

  GameState at(EconomyHarness h, int best, {int rebirths = 0}) => h.newGame().copyWith(
    wallet: h.newGame().wallet.copyWith(gems: 1000000),
    progress: Progress(stage: best, bestStage: best, rebirths: rebirths),
    summonsTotal: 10, // 무료 10연은 지난 뒤
  );

  test('시드 100개 × 소환 40회: 유예 중(스테이지 < untilStage) 전설 0, 넘으면 나온다', () {
    var before = 0;
    var after = 0;
    for (var seed = 1; seed <= 100; seed++) {
      final h = EconomyHarness(seed: seed);
      sys
        ..handle(at(h, until - 1), const Summon(count: 10), h.ctx)
        ..handle(at(h, until - 1), const Summon(count: 10), h.ctx)
        ..handle(at(h, until - 1), const Summon(count: 10), h.ctx)
        ..handle(at(h, until - 1), const Summon(count: 10), h.ctx);
      before += legends(h.of<CrewSummoned>().expand((e) => e.results));
      final h2 = EconomyHarness(seed: seed);
      for (var i = 0; i < 4; i++) {
        sys.handle(at(h2, until), const Summon(count: 10), h2.ctx);
      }
      after += legends(h2.of<CrewSummoned>().expand((e) => e.results));
    }
    expect(before, 0);
    expect(after, greaterThan(0), reason: '1% × 4000장이면 수십 장');
  });

  test('보스·오프라인 카드도(grantCard): 유예 중 전설 → 영웅 · 환생 뒤엔 유예 없음', () {
    final h = EconomyHarness();
    expect(gateFirstLegend(at(h, 10), t, 'legend'), 'hero');
    expect(gateFirstLegend(at(h, 10), t, 'mythic'), 'hero');
    expect(gateFirstLegend(at(h, 10), t, 'rare'), 'rare');
    expect(gateFirstLegend(at(h, until), t, 'legend'), 'legend');
    expect(gateFirstLegend(at(h, 10, rebirths: 1), t, 'legend'), 'legend');
    grantCard(at(h, 10), h.ctx, 'bones', 'legend', 'boss'); // 옥토는 시작 선원 보호로 일반이 된다(starter_guard_test)
    expect(h.of<CardGranted>().single.rarity, 'hero');
  });
}

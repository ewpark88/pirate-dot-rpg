import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 시작 선원 보호(설계서 4.3, sim 검진 2026-10-17 — 옥토 첫 승급이 1~3분): 첫 회차에 시작 선원 카드 구간 전엔
/// 옥토 카드는 어디서 오든 일반, 소환의 일반 위 등급은 옥토에게 가지 않는다(첫 10연 영웅 확정은 남는다).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  final b = t.growth.bossCards;
  final end = b.starterFirstStage + b.starterCount * b.starterEvery;
  final common = t.rarities.rarities.first.id;

  GameState at(EconomyHarness h, int best, {int rebirths = 0, int summons = 0}) => h.newGame().copyWith(
    wallet: h.newGame().wallet.copyWith(gems: 1000000),
    progress: Progress(stage: best, bestStage: best, rebirths: rebirths),
    summonsTotal: summons,
  );

  test('보스·오프라인 카드(grantCard): 구간 전 옥토 희귀 → 일반, 다른 선원·구간 뒤·환생 뒤는 그대로', () {
    final h = EconomyHarness();
    expect(h.of<CardGranted>(), isEmpty);
    grantCard(at(h, 2), h.ctx, b.starterCrew, 'rare', 'boss');
    grantCard(at(h, 2), h.ctx, 'bones', 'rare', 'boss');
    grantCard(at(h, end), h.ctx, b.starterCrew, 'rare', 'boss');
    grantCard(at(h, 2, rebirths: 1), h.ctx, b.starterCrew, 'rare', 'boss');
    expect(h.of<CardGranted>().map((e) => e.rarity), [common, 'rare', 'rare', 'rare']);
  });

  test('시드 100개 × 첫 무료 10연: 영웅 정확히 1장은 그대로, 옥토에게는 일반만', () {
    for (var seed = 1; seed <= 100; seed++) {
      final h = EconomyHarness(seed: seed);
      sys.handle(at(h, 4), Summon(count: t.meta.raw.obj('tutorial').integer('firstTenCount')), h.ctx);
      final rs = h.of<CrewSummoned>().single.results;
      expect(rs.where((r) => r.rarity == 'hero'), hasLength(1), reason: 'seed $seed');
      expect(rs.where((r) => r.crewId == b.starterCrew && r.rarity != common), isEmpty, reason: 'seed $seed');
    }
  });
}

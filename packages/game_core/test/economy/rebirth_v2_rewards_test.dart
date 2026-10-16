import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 환생 v2 3단계: 환생 상자·스킨·칭호·명예 외형·해금 (platform-rebirth-v2 수용 기준 8~11).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  GameState at(int stage, {int rebirths = 0, ShipState ship = const ShipState()}) => h.newGame().copyWith(
    progress: Progress(stage: stage, bestStage: stage, rebirths: rebirths),
    ship: ship,
    crews: const {'octo': CrewState(level: 5)},
    collection: const {'octo'},
  );

  group('환생 상자 (기준 9)', () {
    test('첫 환생: 젬 +50, 영웅 이상 소환 1, 칭호 deckhand, 스킨 coral 보유·장착, RebirthDone에 내용', () {
      final s0 = at(50);
      final s = sys.handle(s0, const Rebirth(), h.ctx)!;
      expect(s.wallet.gems, s0.wallet.gems + 50);
      expect(s.lastSummon, hasLength(1));
      expect(rarityOrder.indexOf(s.lastSummon!.single.rarity), greaterThanOrEqualTo(rarityOrder.indexOf('hero')));
      expect(s.progress.titles, ['deckhand']);
      expect(s.ship.skinsOwned, {'coral'});
      expect(s.ship.skin, 'coral');
      final done = h.of<RebirthDone>().single;
      expect([done.gems, done.summons, done.title, done.skin], [50, 1, 'deckhand', 'coral']);
      expect(h.of<SkinUnlocked>().single.id, 'coral');
    });

    test('4회 → 5회: 젬 90, 소환 2, 스킨 gold — 사용자가 고른 스킨은 바뀌지 않는다', () {
      final s0 = at(
        50,
        rebirths: 4,
        ship: const ShipState(skin: 'coral', skinsOwned: {'coral', 'storm'}, skinChosen: true),
      );
      final s = sys.handle(s0, const Rebirth(), h.ctx)!;
      expect(s.wallet.gems, s0.wallet.gems + 90);
      expect(s.lastSummon, hasLength(2));
      expect(s.ship.skinsOwned, containsAll(['gold']));
      expect(s.ship.skin, 'coral');
      expect(h.of<RebirthDone>().single.skin, 'gold');
    });

    test('젬은 gemsMax에서 멈춘다', () {
      final s0 = at(50, rebirths: 30);
      expect(sys.handle(s0, const Rebirth(), h.ctx)!.wallet.gems, s0.wallet.gems + 150);
    });
  });

  group('명예 외형 (기준 8)', () {
    test('환생해도 외형 단계는 명예로 남는다, 다시 오를 때는 명예를 넘을 때만 ShipLookChanged', () {
      final vs = t.shipParts.byId('cannon').visualStages; // 외형 단계 문턱(레벨)
      final s0 = at(85, ship: ShipState(parts: {'cannon': vs[3], 'hull': 0, 'sail': 0, 'crowsnest': 0, 'cargo': 0}));
      final s1 = sys.handle(s0, const Rebirth(), h.ctx)!;
      expect(s1.ship.level('cannon'), 0);
      expect(partLook(s1, t)['cannon'], 4);
      expect(s1.ship.honorTier, t.shipTiers.tiers.indexOf(t.shipTiers.tierAt(85)));
      h.events.clear();
      final rich = s1.copyWith(wallet: Wallet(gold: BigNum.parse('1e300')));
      final s2 = sys.handle(rich, UpgradePart('cannon', times: vs[3] - 1), h.ctx)!;
      expect(h.of<ShipLookChanged>(), isEmpty);
      sys.handle(s2, UpgradePart('cannon', times: vs[4] - (vs[3] - 1)), h.ctx);
      expect(h.of<ShipLookChanged>().single.stage, 5);
    });
  });

  group('선원 최대 레벨 (기준 10)', () {
    test('환생 2회면 80까지: 레벨 75 선원이 경험치로 76, 1회면 75에서 멈춘다', () {
      final need = t.growth.expToNext['mythic']!;
      GameState s(int rebirths) =>
          at(1, rebirths: rebirths).copyWith(crews: {'octo': CrewState(level: 75, exp: need * 2)});
      expect(crewMaxLevel(s(2), t), 80);
      expect(crewMaxLevel(s(1), t), 75);
      expect(sys.handle(s(2), const MergeAllCards(), h.ctx)!.crews['octo']!.level, 77);
      expect(sys.handle(s(1), const MergeAllCards(), h.ctx)?.crews['octo']!.level ?? 75, 75);
      expect(canMergeAny(s(2), t), isTrue);
      expect(canMergeAny(s(1), t), isFalse);
    });

    test('환생 2회째에 ContentUnlocked(crewMaxLevel, 80)', () {
      sys.handle(at(50, rebirths: 1), const Rebirth(), h.ctx);
      expect(h.of<ContentUnlocked>().map((e) => (e.kind, e.value)), contains(('crewMaxLevel', 80)));
    });
  });

  group('보물 바다 (기준 11, 경제 몫)', () {
    test('환생 3회 + 항로 1 → 다음 회차 treasureSea 1, 그 회차 환생 조각 ×1.5', () {
      final s0 = sys.handle(at(60, rebirths: 3), const SetTreasureRoute(1), h.ctx)!;
      final s1 = sys.handle(s0, const Rebirth(), h.ctx)!;
      expect(s1.progress.treasureSea, 1);
      final run = s1.copyWith(progress: s1.progress.copyWith(stage: 60, bestStage: 60));
      expect(rebirthPreview(run, t).gain, (piecesFor(t, 60) * 1.5).floor());
      expect(treasureHpMultiplier(run, t), 2.0);
    });

    test('항로 2는 환생 3회에서 무시', () {
      final s0 = at(60, rebirths: 3);
      expect(sys.handle(s0, const SetTreasureRoute(2), h.ctx), same(s0));
    });
  });

  test('progress.bossFails: 보스 실패마다 +1, 세이브 왕복·환생 뒤 유지 (S4 안내용)', () {
    final now = EconomyHarness.start;
    final e = CoreEngine(tables: t, clock: ManualClock(now), initial: at(5))..enqueue(const OpSpawnBoss());
    var fails = 0;
    for (var i = 0; i < (t.waves.bossTimeLimitSec + 2) * 1000 ~/ t.waves.tickMs && fails == 0; i++) {
      e.tick();
      fails += e.drainEvents().whereType<BossFailed>().length;
    }
    expect(fails, 1);
    expect(e.state.progress.bossFails, 1);
    expect(SaveCodec.decode(SaveCodec.encode(e.state)).progress.bossFails, 1);
    final reborn = sys.handle(
      at(50).copyWith(progress: const Progress(stage: 50, bestStage: 50, bossFails: 3)),
      const Rebirth(),
      h.ctx,
    )!;
    expect(reborn.progress.bossFails, 3);
  });

  test('보물 바다 회차는 골드 ×goldMultiplier (CombatStats)', () {
    final normal = at(30);
    final sea = normal.copyWith(progress: normal.progress.copyWith(treasureSea: 1));
    expect(CombatStats.of(sea, t).goldMultiplier / CombatStats.of(normal, t).goldMultiplier, closeTo(1.5, 1e-9));
  });

  test('ShipTierUp은 명예 등급을 넘을 때만 (beyondHonor)', () {
    final tier = t.shipTiers.tiers[1];
    expect(beyondHonor(at(1), t, tier), isTrue);
    expect(beyondHonor(at(1, ship: const ShipState(honorTier: 2)), t, tier), isFalse);
  });
}

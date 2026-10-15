import 'dart:io';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 환생 v2 1단계 (docs/specs/platform-rebirth-v2.md 승인): 조각 분리·보물지도 상점 구매·shopView·세이브 v6·운영자.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  GameState withPieces(int pieces, {int earned = -1, Map<String, int> shop = const {}}) => h.newGame().copyWith(
    wallet: Wallet(gold: BigNum.zero, mapPieces: pieces),
    progress: Progress(mapPiecesEarned: earned < 0 ? pieces : earned),
    rebirthShop: shop,
  );

  group('조각 분리 (0절)', () {
    test('rebirthBonus = 모은 조각 누계 × bonusPerPiece — 쓴 조각과 무관', () {
      final s = withPieces(3, earned: 10);
      expect(rebirthBonus(s, t), closeTo(10 * t.meta.rebirth.number('bonusPerPiece'), 1e-12));
    });
  });

  group('상점 구매', () {
    test('기준 1: 조각 10 → startParts 1레벨: 쓸 조각 7, 누계 10, 보너스 그대로, 이벤트', () {
      final s0 = withPieces(10);
      final s = sys.handle(s0, const BuyRebirthUpgrade('startParts'), h.ctx)!;
      expect(s.wallet.mapPieces, 10 - shopCost(t, 'startParts', 0));
      expect(shopCost(t, 'startParts', 0), 3);
      expect(s.progress.mapPiecesEarned, 10);
      expect(rebirthBonus(s, t), rebirthBonus(s0, t));
      expect(s.rebirthShop['startParts'], 1);
      expect(h.of<RebirthUpgradeBought>().single.level, 1);
      expect(h.of<SaveRequested>().single.reason, 'rebirthShop');
    });

    test('비용 = ceil(costBase × costGrowth^level) — 표의 startParts 3,5,6,8,10…', () {
      expect([for (var l = 0; l < 5; l++) shopCost(t, 'startParts', l)], [3, 5, 6, 8, 10]);
      expect([for (var l = 0; l < 2; l++) shopCost(t, 'fleetSlot', l)], [60, 240]);
    });

    test('기준 2: 조각 부족·잠긴 줄·상한·모르는 id는 상태 그대로, 이벤트 없음', () {
      final poor = withPieces(2);
      expect(sys.handle(poor, const BuyRebirthUpgrade('startParts'), h.ctx), same(poor));
      // 2줄 잠김: 상점에 쓴 누계 29 (< 30)
      final locked = withPieces(500, shop: const {'startParts': 4, 'discount': 1}); // 3+5+6+8 + 4 = 26
      expect(shopSpent(locked, t), lessThan(30));
      expect(sys.handle(locked, const BuyRebirthUpgrade('offline'), h.ctx), same(locked));
      final maxed = withPieces(500, shop: const {'bossTime': 5});
      expect(sys.handle(maxed, const BuyRebirthUpgrade('bossTime'), h.ctx), same(maxed));
      expect(sys.handle(poor, const BuyRebirthUpgrade('anchor'), h.ctx), same(poor));
      expect(h.events, isEmpty);
    });

    test('줄 해금: 쓴 누계 30이면 2줄, 150이면 3줄', () {
      expect(shopRowUnlocked(withPieces(0), t, 1), isTrue);
      expect(shopRowUnlocked(withPieces(0, shop: const {'startParts': 5}), t, 2), isTrue); // 3+5+6+8+10 = 32
      expect(shopRowUnlocked(withPieces(0, shop: const {'startParts': 5}), t, 3), isFalse);
    });

    test('shopView: 9칸, 레벨·상한·다음 비용·해금·살 수 있음, 쓴 누계와 다음 줄까지', () {
      final v = shopView(withPieces(5, shop: const {'startParts': 1}), t);
      expect(v.items, hasLength(9));
      final sp = v.items.firstWhere((i) => i.id == 'startParts');
      expect([sp.level, sp.maxLevel, sp.cost, sp.unlocked, sp.affordable], [1, 10, 5, true, true]);
      final off = v.items.firstWhere((i) => i.id == 'offline');
      expect([off.unlocked, off.affordable], [false, false]);
      expect(v.spentTotal, 3);
      expect(v.nextRowAt, 30);
      final maxed = shopView(
        withPieces(999, shop: const {'bossTime': 5}),
        t,
      ).items.firstWhere((i) => i.id == 'bossTime');
      expect(maxed.cost, isNull);
      expect(maxed.effectNext, isNull);
    });
  });

  group('환생·운영자', () {
    test('환생은 쓸 조각과 누계에 같은 양을 더한다', () {
      final s0 = withPieces(
        4,
        earned: 20,
      ).copyWith(progress: const Progress(stage: 50, bestStage: 50, mapPiecesEarned: 20));
      final s = sys.handle(s0, const Rebirth(), h.ctx)!;
      final gain = piecesFor(t, 50);
      expect(s.wallet.mapPieces, 4 + gain);
      expect(s.progress.mapPiecesEarned, 20 + gain);
    });

    test('기준 15: OpGrantPieces(500)는 둘 다 늘린다, OpSetRebirths(10)는 다음 틱에 스킨 4·칭호 4(소급, 상자 없음)', () {
      final s1 = sys.handle(withPieces(0), const OpGrantPieces(500), h.ctx)!;
      expect([s1.wallet.mapPieces, s1.progress.mapPiecesEarned], [500, 500]);
      final s2 = sys.update(sys.handle(s1, const OpSetRebirths(10), h.ctx)!, h.ctx);
      expect(s2.progress.rebirths, 10);
      expect(s2.ship.skinsOwned, {'coral', 'storm', 'gold', 'phantom'});
      expect(s2.ship.skin, 'coral');
      expect(s2.progress.titles, ['deckhand', 'navigator', 'captain', 'admiral']);
      expect(s2.wallet.gems, s1.wallet.gems);
    });
  });

  group('세이브 v6', () {
    test('기준 12: v5(환생 3회·조각 120·최고 90) → v6 + 첫 틱: 누계 120, 명예 등급 = 최고 스테이지 등급, 스킨 coral·storm(coral 장착), 칭호 2개', () {
      final v5 = SaveCodec.decode(File('test/fixtures/saves/v5_rebirth3.json').readAsStringSync());
      expect(v5.progress.mapPiecesEarned, 120);
      expect(v5.wallet.mapPieces, 120);
      expect(v5.rebirthShop, isEmpty);
      final s = sys.update(v5, h.ctx);
      expect(s.ship.honorTier, t.shipTiers.tiers.indexOf(t.shipTiers.tierAt(90)));
      expect(s.ship.skinsOwned, {'coral', 'storm'});
      expect(s.ship.skin, 'coral');
      expect(s.progress.titles, ['deckhand', 'navigator']);
    });

    test('v6 왕복: 상점·명예·스킨·칭호·보물 항로·현상금 자리', () {
      final s = h.newGame().copyWith(
        rebirthShop: const {'discount': 3},
        progress: const Progress(mapPiecesEarned: 9, titles: ['deckhand'], treasureSea: 1, treasureRoute: 2),
        ship: const ShipState(
          honorParts: {'cannon': 4},
          honorTier: 2,
          skin: 'coral',
          skinsOwned: {'coral'},
          skinChosen: true,
        ),
        settings: const Settings(title: 'deckhand'),
        bounty: const {'tickets': 3},
      );
      final back = SaveCodec.decode(SaveCodec.encode(s));
      expect(back.toJson(), s.toJson());
    });
  });

  test('명령·이벤트 JSON 왕복', () {
    for (final c in const <Command>[
      BuyRebirthUpgrade('discount'),
      SelectShipSkin('coral'),
      SelectShipSkin(),
      SelectTitle('deckhand'),
      SetTreasureRoute(2),
      SetTreasureRoute(),
      OpGrantPieces(500),
      OpSetRebirths(10),
    ]) {
      expect(Command.fromJson(c.toJson()).toJson(), c.toJson(), reason: c.type);
    }
    for (final e in const <GameEvent>[
      RebirthUpgradeBought(1, id: 'discount', level: 2),
      SkinUnlocked(1, id: 'coral'),
      ContentUnlocked(1, kind: 'crewMaxLevel', value: 80),
      RebirthDone(1, gain: 44, pieces: 44, rebirths: 1, gems: 50, summons: 1, title: 'deckhand', skin: 'coral'),
      RebirthDone(1, gain: 44, pieces: 44, rebirths: 2),
    ]) {
      expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson(), reason: e.type);
    }
  });
}

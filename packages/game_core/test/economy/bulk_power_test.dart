import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 일괄 강화(1·5·10·20·50·최대)와 함대 전투력 (사용자 지시 2026-10-15).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  BigNum loopCost(ShipPartDef def, int from, int n) {
    var sum = BigNum.zero;
    for (var l = from; l < from + n; l++) {
      sum = sum + partCost(def, l);
    }
    return sum;
  }

  group('비용 합·살 수 있는 수 (공식)', () {
    test('partCostSum = 레벨마다 더한 값 (큰 레벨에서도)', () {
      for (final def in t.shipParts.parts) {
        for (final (from, n) in [(0, 1), (0, 50), (37, 20), (900, 7)]) {
          expect(
            partCostSum(def, from, n).closeTo(loopCost(def, from, n)),
            isTrue,
            reason: '${def.id} $from+$n',
          );
        }
        expect(partCostSum(def, 5, 0), BigNum.zero);
      }
    });

    test('affordableLevels = 골드로 살 수 있는 최대 수, 최대 레벨에서 멈춘다', () {
      final cannon = t.shipParts.byId('cannon');
      for (final (from, n) in [(0, 1), (0, 3), (12, 40), (400, 123)]) {
        final exact = partCostSum(cannon, from, n); // 판정 기준은 공식 합 (반복 합과는 1e-9 안에서 같다)
        expect(affordableLevels(cannon, from, exact), n, reason: '정확히 $n개 값');
        expect(
          affordableLevels(cannon, from, exact - BigNum.from(1e-9).times(exact.toDouble())),
          n - 1,
          reason: '조금 모자람',
        );
      }
      expect(affordableLevels(cannon, 0, BigNum.from(9)), 0);
      final sail = t.shipParts.byId('sail');
      expect(affordableLevels(sail, 25, BigNum.parse('1e300')), sail.maxLevel! - 25);
      expect(affordableLevels(sail, sail.maxLevel!, BigNum.parse('1e300')), 0);
    });
  });

  group('UpgradePart 일괄', () {
    test('times 50: 50레벨, 골드는 공식 합만큼, 마일스톤(milestoneEvery 배수) 이벤트', () {
      final cannon = t.shipParts.byId('cannon');
      final s0 = h.newGame(gold: partCostSum(cannon, 0, 50).times(1.5));
      final s = sys.handle(s0, const UpgradePart('cannon', times: 50), h.ctx)!;
      expect(s.ship.level('cannon'), 50);
      expect((s0.wallet.gold - s.wallet.gold).closeTo(partCostSum(cannon, 0, 50)), isTrue);
      final m = cannon.milestoneEvery!;
      expect(h.of<PartMilestone>().map((e) => e.level), [for (var lv = m; lv <= 50; lv += m) lv]);
      expect(h.of<PartUpgraded>().last.level, 50);
    });

    test('max: 골드로 가능한 만큼 · 최대 레벨 경계', () {
      final cannon = t.shipParts.byId('cannon');
      final gold = partCostSum(cannon, 10, 33).times(1.0000001);
      final s0 = h.newGame(gold: gold).copyWith(ship: const ShipState().withLevel('cannon', 10));
      final s = sys.handle(s0, const UpgradePart.max('cannon'), h.ctx)!;
      expect(s.ship.level('cannon'), 43);
      final sail = sys.handle(
        h.newGame(gold: BigNum.parse('1e300')).copyWith(ship: const ShipState().withLevel('sail', 28)),
        const UpgradePart.max('sail'),
        h.ctx,
      )!;
      expect(sail.ship.level('sail'), t.shipParts.byId('sail').maxLevel);
    });

    test('max로 0개면 상태 그대로', () {
      final s0 = h.newGame(gold: BigNum.from(9));
      expect(sys.handle(s0, const UpgradePart.max('cannon'), h.ctx), same(s0));
    });

    test('JSON: times 없으면 1, max 왕복', () {
      expect(
        Command.fromJson(const {'type': 'upgradePart', 'part': 'hull'}).toJson(),
        const UpgradePart('hull').toJson(),
      );
      const m = UpgradePart.max('cargo');
      final back = Command.fromJson(m.toJson()) as UpgradePart;
      expect(back.max, isTrue);
      expect(back.part, 'cargo');
    });
  });

  group('함대 전투력', () {
    GameState armed(Map<String, int> parts) => h.newGame().copyWith(
      crews: const {'octo': CrewState(level: 10), 'turtle': CrewState(level: 10)},
      fleet: const ['octo', 'turtle'],
      fleetInit: true,
      ship: ShipState(parts: parts),
    );

    test('fleetPower.dps = 출전 편성 DPS, power = √(DPS × 배 최대 HP)', () {
      final s = armed(const {'cannon': 10, 'hull': 10});
      final p = fleetPower(s, t);
      expect(p.dps.closeTo(fleetDps(s, t, activeFleet(s, t))), isTrue);
      expect(p.power.closeTo((p.dps * shipMaxHp(t.shipParts, 10)).pow(0.5)), isTrue);
    });

    test('강화하면 전투력이 오른다 — 대포·선체·돛·망루, 화물칸은 골드 배율', () {
      final s = armed(const {'cannon': 10, 'hull': 10, 'sail': 5, 'crowsnest': 5, 'cargo': 5});
      for (final id in ['cannon', 'hull', 'sail', 'crowsnest']) {
        final p = previewUpgrade(s.copyWith(wallet: s.wallet.copyWith(gold: BigNum.parse('1e30'))), t, id, times: 5);
        expect(p.powerAfter > p.powerBefore, isTrue, reason: id);
      }
      final cargo = previewUpgrade(
        s.copyWith(wallet: s.wallet.copyWith(gold: BigNum.parse('1e30'))),
        t,
        'cargo',
        times: 5,
      );
      expect(cargo.goldMultiplierAfter, greaterThan(cargo.goldMultiplierBefore));
      expect(cargo.powerAfter.closeTo(cargo.powerBefore), isTrue);
    });

    test('previewUpgrade = UpgradePart 실행 결과와 같은 레벨·비용 (골드가 모자라면 살 수 있는 만큼)', () {
      final cannon = t.shipParts.byId('cannon');
      final s = armed(const {'cannon': 20}).copyWith(wallet: Wallet(gold: partCostSum(cannon, 20, 7).times(1.0000001)));
      final p = previewUpgrade(s, t, 'cannon', times: 20);
      expect(p.levels, 7);
      expect(p.cost.closeTo(partCostSum(cannon, 20, 7)), isTrue);
      final after = sys.handle(s, const UpgradePart('cannon', times: 20), h.ctx)!;
      expect(after.ship.level('cannon'), 20 + p.levels);
      expect(fleetPower(after, t).power.closeTo(p.powerAfter), isTrue);
      expect(previewUpgrade(s, t, 'cannon', max: true).levels, 7);
    });
  });
}

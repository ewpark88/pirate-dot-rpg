import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

void main() {
  final t = GameTables.load();
  final parts = t.shipParts;

  bool near(BigNum a, num b) => a.closeTo(BigNum.from(b));

  group('배 부위 효과 (설계서 4.2)', () {
    // 기대값은 표에서 읽는다(골드 재조정 2026-10-16처럼 수치가 바뀌어도 공식만 검사).
    final cannon = parts.byId('cannon');
    final hull = parts.byId('hull');
    final cargo = parts.byId('cargo');
    num exp(ShipPartDef p, int lv) =>
        p.base * math.pow(p.growth, partStep(p, lv)) * math.pow(p.milestoneMultiplier, lv ~/ p.milestoneEvery!);

    test('대포 공격력 = base × growth^Lv, milestoneEvery마다 × milestoneMultiplier', () {
      final m = cannon.milestoneEvery!;
      expect(near(shipAttack(parts, 0), cannon.base), isTrue);
      expect(near(shipAttack(parts, m - 1), exp(cannon, m - 1)), isTrue);
      expect(near(shipAttack(parts, m), exp(cannon, m)), isTrue);
      expect(near(shipAttack(parts, m * 2), exp(cannon, m * 2)), isTrue);
    });

    test('대포 Lv1000도 BigNum으로 넘치지 않는다', () {
      final big = shipAttack(parts, 1000);
      expect(
        big.log10,
        closeTo(
          (math.log(cannon.base) +
                  partStep(cannon, 1000) * math.log(cannon.growth) +
                  (1000 ~/ cannon.milestoneEvery!) * math.log(cannon.milestoneMultiplier)) /
              math.ln10,
          1e-6,
        ),
      );
    });

    test('선체 HP = base × growth^Lv, milestoneEvery마다 × milestoneMultiplier', () {
      expect(near(shipMaxHp(parts, 0), hull.base), isTrue);
      expect(near(shipMaxHp(parts, hull.milestoneEvery!), exp(hull, hull.milestoneEvery!)), isTrue);
    });

    test('돛 공격 속도 = 1 + 0.05 × Lv, 상한 ×2.5', () {
      expect(attackSpeedMultiplier(parts, 0), 1);
      expect(attackSpeedMultiplier(parts, 10), closeTo(1.5, 1e-12));
      expect(attackSpeedMultiplier(parts, 30), closeTo(2.5, 1e-12));
      expect(attackSpeedMultiplier(parts, 99), closeTo(2.5, 1e-12));
    });

    test('망루 치명타 = 5% + 1% × Lv, 상한 50%', () {
      expect(critChance(parts, 0), closeTo(0.05, 1e-12));
      expect(critChance(parts, 20), closeTo(0.25, 1e-12));
      expect(critChance(parts, 45), closeTo(0.5, 1e-12));
      expect(critChance(parts, 99), closeTo(0.5, 1e-12));
    });

    test('화물칸 골드 배율 = base + growth × Lv, milestoneEvery마다 × milestoneMultiplier', () {
      final m = cargo.milestoneEvery!;
      expect(goldMultiplier(parts, 0), cargo.base);
      expect(goldMultiplier(parts, m - 1), closeTo(cargo.base + cargo.growth * partStep(cargo, m - 1), 1e-9));
      expect(
        goldMultiplier(parts, m),
        closeTo((cargo.base + cargo.growth * partStep(cargo, m)) * cargo.milestoneMultiplier, 1e-9),
      );
    });

    test('강화 비용 = costBase × costGrowth^Lv', () {
      for (final p in parts.parts) {
        expect(near(partCost(p, 0), p.costBase), isTrue);
        expect(near(partCost(p, 3), p.costBase * math.pow(p.costGrowth, partStep(p, 3))), isTrue);
      }
    });

    test('ShipStats.of는 ShipState의 레벨로 다섯 값을 모은다', () {
      final m = cannon.milestoneEvery!;
      final ship = ShipState(parts: {'cannon': m, 'hull': 3, 'sail': 10, 'crowsnest': 20, 'cargo': 2});
      final s = ShipStats.of(parts, ship);
      expect(near(s.attack, exp(cannon, m)), isTrue);
      expect(near(s.maxHp, exp(hull, 3)), isTrue);
      expect(s.attackSpeed, closeTo(1.5, 1e-12));
      expect(s.critChance, closeTo(0.25, 1e-12));
      expect(s.critMultiplier, 2);
      expect(s.goldMultiplier, closeTo(cargo.base + cargo.growth * partStep(cargo, 2), 1e-9));
    });
  });

  group('가속 곡선 accelLevels (골드 재조정 2026-10-16)', () {
    ShipPartDef accel(double? a) => ShipPartDef.fromJson(
      JsonReader({
        'id': 'cannon',
        'stat': 'attack',
        'formula': 'exp',
        'base': 4,
        'growth': 1.3,
        'costBase': 10,
        'costGrowth': 1.5,
        'maxLevel': null,
        'milestoneEvery': null,
        'milestoneMultiplier': 1,
        'visualStages': [1],
        'nameKey': 'x',
        'accelLevels': ?a,
      }, 'test'),
    );

    test('레벨 자리 = Lv + Lv² ÷ 2A, 없으면 Lv', () {
      expect(partStep(accel(null), 6), 6);
      expect(partStep(accel(4), 6), 6 + 36 / 8);
      expect(near(partCost(accel(4), 6), 10 * math.pow(1.5, 6 + 36 / 8)), isTrue);
      expect(near(partEffect(accel(4), 6), 4 * math.pow(1.3, 6 + 36 / 8)), isTrue);
    });

    test('비용 합·살 수 있는 레벨 수가 한 레벨씩 더한 것과 같다', () {
      final d = accel(4);
      final sum = partCost(d, 3) + partCost(d, 4) + partCost(d, 5);
      expect(partCostSum(d, 3, 3).closeTo(sum), isTrue);
      expect(affordableLevels(d, 3, sum), 3);
      expect(affordableLevels(d, 3, sum - BigNum.one), 2);
    });

    test('가속이 있으면 레벨마다 비용 비율이 커진다(강화가 갈수록 드물다)', () {
      final d = accel(4);
      final early = (partCost(d, 2) / partCost(d, 1)).toDouble();
      final late = (partCost(d, 12) / partCost(d, 11)).toDouble();
      expect(late, greaterThan(early));
    });
  });

  group('선원 파워 (설계서 4.3.1)', () {
    test('레벨 → 등급', () {
      expect(rarityOfLevel(t.rarities, 1).id, 'common');
      expect(rarityOfLevel(t.rarities, 15).id, 'common');
      expect(rarityOfLevel(t.rarities, 16).id, 'rare');
      expect(rarityOfLevel(t.rarities, 46).id, 'legend');
      expect(rarityOfLevel(t.rarities, 75).id, 'mythic');
    });

    test('승급 횟수 = 등급 순번', () {
      expect(promotionCount(t.rarities, 15), 0);
      expect(promotionCount(t.rarities, 16), 1);
      expect(promotionCount(t.rarities, 61), 4);
    });

    test('파워 배율 = (1 + 0.08 × (Lv - 1)) × 1.35^승급', () {
      expect(crewPowerMultiplier(t.growth, t.rarities, 1), closeTo(1, 1e-12));
      expect(crewPowerMultiplier(t.growth, t.rarities, 15), closeTo(1 + 0.08 * 14, 1e-12));
      expect(crewPowerMultiplier(t.growth, t.rarities, 16), closeTo((1 + 0.08 * 15) * 1.35, 1e-12));
      expect(crewPowerMultiplier(t.growth, t.rarities, 75), closeTo((1 + 0.08 * 74) * math.pow(1.35, 4), 1e-9));
    });

    test('같은 레벨 구간 경계에서 승급 쪽이 항상 강하다', () {
      for (final r in t.rarities.rarities.skip(1)) {
        expect(
          crewPowerMultiplier(t.growth, t.rarities, r.levelMin),
          greaterThan(crewPowerMultiplier(t.growth, t.rarities, r.levelMin - 1)),
        );
      }
    });
  });
}

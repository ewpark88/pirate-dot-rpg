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
        p.base * math.pow(p.growth, lv) * math.pow(p.milestoneMultiplier, lv ~/ p.milestoneEvery!);

    test('대포 공격력 = base × growth^Lv, milestoneEvery마다 × milestoneMultiplier', () {
      final m = cannon.milestoneEvery!;
      expect(near(shipAttack(parts, 0), cannon.base), isTrue);
      expect(near(shipAttack(parts, m - 1), exp(cannon, m - 1)), isTrue);
      expect(near(shipAttack(parts, m), exp(cannon, m)), isTrue);
      expect(near(shipAttack(parts, m * 2), exp(cannon, m * 2)), isTrue);
      expect(shipAttack(parts, m) / shipAttack(parts, m - 1) > BigNum.from(cannon.milestoneMultiplier), isTrue);
    });

    test('대포 Lv1000도 BigNum으로 넘치지 않는다', () {
      final big = shipAttack(parts, 1000);
      expect(
        big.log10,
        closeTo(
          (math.log(cannon.base) +
                  1000 * math.log(cannon.growth) +
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
      expect(goldMultiplier(parts, m - 1), closeTo(cargo.base + cargo.growth * (m - 1), 1e-12));
      expect(goldMultiplier(parts, m), closeTo((cargo.base + cargo.growth * m) * cargo.milestoneMultiplier, 1e-12));
    });

    test('강화 비용 = costBase × costGrowth^Lv', () {
      for (final p in parts.parts) {
        expect(near(partCost(p, 0), p.costBase), isTrue);
        expect(near(partCost(p, 3), p.costBase * math.pow(p.costGrowth, 3)), isTrue);
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
      expect(s.goldMultiplier, closeTo(cargo.base + cargo.growth * 2, 1e-12));
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

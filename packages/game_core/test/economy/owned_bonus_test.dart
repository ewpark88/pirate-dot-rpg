import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 설계서 4.3 보유 효과(선원 하나당 Lv × ownedBonusPerLevel)·도감 보너스는 4.8 ‘마지막 % 합’에 더한다.
void main() {
  final t = EconomyHarness.tables;
  final h = EconomyHarness();

  GameState owning(Map<String, CrewState> crews) => h.newGame().copyWith(crews: crews, collection: crews.keys.toSet());

  test('보유 효과 = 보유 선원 레벨 합 × ownedBonusPerLevel (출전 여부와 무관)', () {
    final s = owning(const {'octo': CrewState(level: 10), 'turtle': CrewState(level: 30)});
    expect(ownedBonus(s, t), closeTo(40 * t.growth.ownedBonusPerLevel, 1e-12));
    expect(ownedBonus(h.newGame(), t), 0);
  });

  test('피해 % 합 = 환생 + 보유 효과 + 도감', () {
    final crews = {for (final c in t.crews.crews.take(5)) c.id: const CrewState(level: 20)};
    final s = owning(crews).copyWith(wallet: h.newGame().wallet.copyWith(mapPieces: 3));
    expect(
      damageBonus(s, t),
      closeTo(rebirthBonus(s, t) + ownedBonus(s, t) + collectionBonus(s, t).attackBonus, 1e-12),
    );
    expect(collectionBonus(s, t).attackBonus, greaterThan(0));
  });

  test('오프라인 DPS 추정도 보유 효과를 반영한다', () {
    final base = owning(const {'octo': CrewState(level: 5)}).copyWith(fleet: const ['octo'], fleetInit: true);
    final more = base.copyWith(crews: {...base.crews, 'manta': const CrewState(level: 60)});
    final ratio = fleetDps(more, t, const ['octo']) / fleetDps(base, t, const ['octo']);
    expect(ratio.toDouble(), closeTo((1 + damageBonus(more, t)) / (1 + damageBonus(base, t)), 1e-9));
  });

  test('전투 CombatStats.bonus = damageBonus (+ 함포 지원 버프)', () {
    final s = owning(const {'octo': CrewState(level: 10), 'manta': CrewState(level: 50)});
    expect(CombatStats.of(s, t).bonus, closeTo(damageBonus(s, t), 1e-12));
    expect(CombatStats.of(s, t).bonus, greaterThan(rebirthBonus(s, t)));
  });
}

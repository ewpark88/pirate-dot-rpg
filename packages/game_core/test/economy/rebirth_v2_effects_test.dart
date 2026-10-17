import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_core/src/economy/rebirth_shop.dart' show bossGuard;
import 'package:game_core/testing.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 환생 v2 2단계: 보물지도 상점 효과 (platform-rebirth-v2 수용 기준 3~7 + 조각 배수·지름길).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  GameState shop(Map<String, int> levels, {int stage = 1, int rebirths = 0}) => h.newGame().copyWith(
    rebirthShop: levels,
    progress: Progress(stage: stage, bestStage: stage, rebirths: rebirths),
  );

  test('기준 3: startParts 2 → 환생 뒤 대포·선체·화물 10, 돛·망루 2, 골드 0, ShipLookChanged 없음', () {
    final s0 = shop(const {'startParts': 2}, stage: 50).copyWith(wallet: Wallet(gold: BigNum.from(1e9)));
    final s = sys.handle(s0, const Rebirth(), h.ctx)!;
    expect(s.ship.parts, {'cannon': 10, 'hull': 10, 'sail': 2, 'crowsnest': 2, 'cargo': 10});
    expect(s.wallet.gold, BigNum.zero);
    expect(h.of<ShipLookChanged>(), isEmpty);
  });

  test('기준 4: discount 5 → 대포 0→1 비용 = 원래 × 0.8, 살 수 있는 수도 할인 반영', () {
    final s = shop(const {'discount': 5});
    expect(upgradeCostMultiplier(s, t), closeTo(0.8, 1e-12));
    final cannon = t.shipParts.byId('cannon');
    final gold = partCost(cannon, 0).times(0.8);
    final after = sys.handle(s.copyWith(wallet: Wallet(gold: gold)), const UpgradePart('cannon'), h.ctx)!;
    expect(after.ship.level('cannon'), 1);
    expect(after.wallet.gold.toDouble(), closeTo(0, 1e-9));
    expect(previewUpgrade(s.copyWith(wallet: Wallet(gold: gold)), t, 'cannon').cost.closeTo(gold), isTrue);
  });

  test(
    '기준 5: 보스 시간 제한 없음 · bossTime(철갑판) 3 → 보스전·현상금 배 피해 −12% · critChance 10 + 망루 최대 → 치명 ≤ 0.5 · critDamage +0.1/레벨',
    () {
      final now = DateTime.utc(2026, 11);
      final s0 = shop(const {'bossTime': 3}, stage: 5);
      final e = CoreEngine(tables: t, clock: ManualClock(now), initial: s0)
        ..enqueue(const OpSpawnBoss())
        ..tick();
      final spawned = e.drainEvents().whereType<BossSpawned>().single;
      expect(spawned.timeLimitTicks, 0, reason: '2026-10-17 사용자 결정: 보스 시간 없음 — 침몰로만 실패');
      expect(bossGuard(s0, t), closeTo(0.12, 1e-9));
      final f = Field(stage: 5, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000))
        ..bossGuard = bossGuard(s0, t)
        ..bossActive = true;
      expect(f.hurtShip(BigNum.from(50), 1).toDouble(), closeTo(44, 1e-9), reason: '보스전 피해 × (1 − 0.12)');
      f.bossActive = false;
      expect(f.hurtShip(BigNum.from(50), 1).toDouble(), closeTo(50, 1e-9), reason: '무리전은 그대로');
      final crit = shop(const {
        'critChance': 10,
        'critDamage': 4,
      }).copyWith(ship: const ShipState().withLevel('crowsnest', 45));
      final stats = CombatStats.of(crit, t);
      expect(stats.critChance, lessThanOrEqualTo(t.shipParts.critChanceMax));
      expect(stats.critMultiplier, closeTo(t.shipParts.critMultiplier + 0.4, 1e-9));
      expect(
        CombatStats.of(shop(const {'critChance': 3}), t).critChance,
        closeTo(ShipStats.of(t.shipParts, const ShipState()).critChance + 0.03, 1e-9),
      );
    },
  );

  test('기준 6: offline 2 → offlineMaxSec 36000, 오프라인 보상이 같은 값을 쓴다', () {
    final s = shop(const {'offline': 2});
    expect(offlineMaxSec(s, t), t.meta.offlineMaxSec + 7200);
    final away = s.copyWith(
      crews: const {'octo': CrewState(level: 5)},
      savedAt: EconomyHarness.start.subtract(const Duration(hours: 20)),
    );
    expect(offlinePreview(away, t, EconomyHarness.start)!.seconds, 36000);
  });

  test('기준 7: 칸 + fleetSlot 1 → 출전 칸 하나 더, 상한 fleetSlotsMax', () {
    const stage = 40;
    final base = t.shipTiers.tierAt(stage).slots;
    final s = shop(const {'fleetSlot': 1}, stage: stage).copyWith(
      crews: {for (final c in t.crews.crews.take(8)) c.id: const CrewState()},
      fleetInit: true,
    );
    expect(fleetSlots(s, t), base + 1);
    final placed = sys.handle(s, SetFleetSlot(base, t.crews.crews[0].id), h.ctx)!;
    expect(placed.fleet.length, base + 1);
    expect(fleetSlots(shop(const {'fleetSlot': 9}, stage: 9999), t), t.meta.rebirth.integer('fleetSlotsMax'));
  });

  test('pieceGain 3 → 환생 조각 ×1.3 (내림), 미리보기와 같다', () {
    final s = shop(const {'pieceGain': 3}, stage: 60);
    final want = (piecesFor(t, 60) * 1.3).floor();
    expect(rebirthPreview(s, t).gain, want);
    expect(sys.handle(s, const Rebirth(), h.ctx)!.wallet.mapPieces, want);
  });

  test('fastSail 2 → 빠른 항해 범위 fraction + 0.1', () {
    expect(fastSailFraction(shop(const {'fastSail': 2}), t), closeTo(t.waves.rebirthSkip.fraction + 0.1, 1e-12));
  });
}

import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 자동 강화는 광고 보상으로만 (사용자 결정 2026-10-16): 평소엔 수동, 광고 1회 = 10분.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  final r = t.ads.placements.firstWhere((p) => p.id == 'autoUpgrade').reward;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  GameState rich() => h.newGame(gold: BigNum.from(1000));

  test('버프가 없으면 골드가 있어도 아무것도 사지 않는다(수동만)', () {
    final s0 = rich();
    var s = s0;
    for (var i = 0; i < 100; i++) {
      s = sys.update(s, h.ctx);
    }
    expect(s.ship.parts, s0.ship.parts);
  });

  test('광고 → 10분 버프, 버프 중 intervalSec마다 가장 싼 부위 하나', () {
    final s1 = sys.handle(rich(), const GrantAdReward(AdPlacement.autoUpgrade), h.ctx)!;
    expect(autoUpgradeRemaining(s1, EconomyHarness.start), Duration(seconds: r.integer('durationSec')));
    final pick = autoUpgradePick(s1, t);
    expect(pick, isNotNull);
    expect(pick, isNot('cargo'), reason: '금고가 비어 있으면 화물칸은 사지 않는다');
    final s2 = sys.update(s1, h.ctx); // tick 0은 intervalSec의 배수
    expect(s2.ship.level(pick!), s1.ship.level(pick) + 1);
  });

  test('겹쳐 보면 maxStackSec까지만', () {
    var s = rich();
    for (var i = 0; i < 6; i++) {
      s = addAutoUpgrade(s, t, EconomyHarness.start);
    }
    expect(autoUpgradeRemaining(s, EconomyHarness.start), Duration(seconds: r.integer('maxStackSec')));
  });

  test('금고가 거의 차면 화물칸도 후보 — 다른 부위가 모두 화물칸보다 비싸면 화물칸', () {
    final s = rich();
    final pricey = s.copyWith(
      ship: const ShipState(parts: {'cannon': 9, 'hull': 9, 'sail': 30, 'crowsnest': 45, 'cargo': 0}),
    );
    final full = pricey.copyWith(wallet: pricey.wallet.copyWith(gold: goldCapacity(pricey, t)));
    expect(autoUpgradePick(full, t), 'cargo');
    final empty = pricey.copyWith(wallet: pricey.wallet.copyWith(gold: BigNum.zero));
    expect(autoUpgradePick(empty, t), isNull);
  });
}

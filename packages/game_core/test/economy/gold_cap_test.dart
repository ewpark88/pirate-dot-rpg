import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 화물칸 = 골드 금고 용량 (docs/specs/economy-cargo-capacity.md 수용 기준 1~5, 사용자 결정 2026-10-16).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  GameState withGold(BigNum gold, {int cargo = 0}) => h
      .newGame(gold: gold)
      .copyWith(ship: ShipState(parts: {'cannon': 0, 'hull': 0, 'sail': 0, 'crowsnest': 0, 'cargo': cargo}));

  test('기준 1: 용량 − 5에서 20이 들어오면 용량까지, 넘친 15', () {
    final cap = goldCapacity(withGold(BigNum.zero), t);
    final r = addGold(withGold(cap - BigNum.from(5)), t, BigNum.from(20));
    expect(r.state.wallet.gold, cap);
    expect(r.added.closeTo(BigNum.from(5)), isTrue);
    expect(r.lost.closeTo(BigNum.from(15)), isTrue);
  });

  test('기준 2: 이미 용량을 넘게 가졌으면(옛 세이브) 깎지 않고 더 안 쌓인다', () {
    final cap = goldCapacity(withGold(BigNum.zero), t);
    final over = cap.times(3);
    final r = addGold(withGold(over), t, BigNum.from(100));
    expect(r.state.wallet.gold, over);
    expect(r.added, BigNum.zero);
    expect(goldRoom(r.state, t), BigNum.zero);
  });

  test('기준 3: 오프라인 골드는 여유까지 — OfflineReward는 계산값, 지갑은 용량, GoldOverflow로 잘린 몫', () {
    final s0 = withGold(BigNum.zero).copyWith(savedAt: EconomyHarness.start.subtract(const Duration(hours: 8)));
    final s = sys.handle(s0, const ClaimOffline(), h.ctx)!;
    final e = h.of<OfflineReward>().single;
    final cap = goldCapacity(s0, t);
    expect(s.wallet.gold, e.gold < cap ? e.gold : cap);
    if (e.gold > cap) expect(h.of<GoldOverflow>().single.lost.closeTo(e.gold - cap), isTrue);
    expect(s.lastOfflineGold, s.wallet.gold);
  });

  test('기준 4: 화물칸 강화 비용 = 그 레벨 용량 × costRatio', () {
    final cargo = t.shipParts.byId('cargo');
    for (final lv in [0, 5, 12]) {
      expect(partCost(cargo, lv).closeTo(partEffect(cargo, lv).times(cargo.costRatio!)), isTrue);
    }
  });

  test('80% 이상이면 goldNearFull (UI 미리 경고)', () {
    final cap = goldCapacity(withGold(BigNum.zero), t);
    expect(goldNearFull(withGold(cap.times(0.79)), t), isFalse);
    expect(goldNearFull(withGold(cap.times(0.81)), t), isTrue);
  });

  test('GoldOverflow JSON 왕복', () {
    final e = GoldOverflow(3, lost: BigNum.parse('1.5e6'));
    expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson());
  });
}

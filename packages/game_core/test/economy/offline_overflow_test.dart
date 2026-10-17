import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 실기기 2026-10-17(S1 s01_start): 화물칸이 가득인 채 16분 떠났다 오면 오프라인 골드 581이 0으로 사라짐 →
/// 복귀 보상은 화물칸 용량 × offline.capMultiplier까지 싣는다(금고 규칙 자체는 그대로 — 처치 골드는 용량까지).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;

  test('금고가 가득이어도 복귀 보상은 용량 × capMultiplier까지 들어온다', () {
    final h = EconomyHarness();
    final base = h.newGame().copyWith(crews: {'octo': const CrewState(level: 5)});
    final cap = goldCapacity(base, t);
    final full = base.copyWith(
      wallet: base.wallet.copyWith(gold: cap),
      savedAt: EconomyHarness.start.subtract(const Duration(hours: 8)),
    );
    final s = sys.handle(full, const ClaimOffline(), h.ctx)!;
    final e = h.of<OfflineReward>().single;
    final limit = cap.times(offlineCapScale(t));
    expect(s.wallet.gold > cap, isTrue, reason: '가득이어도 받는다');
    expect(s.wallet.gold.closeTo(cap + e.gold < limit ? cap + e.gold : limit), isTrue);
    expect(offlineCapScale(t), greaterThan(1));
  });
}

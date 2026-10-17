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
    final limit = cap.times(offlineCapScale(t, full));
    expect(s.wallet.gold > cap, isTrue, reason: '가득이어도 받는다');
    expect(s.wallet.gold.closeTo(cap + e.gold < limit ? cap + e.gold : limit), isTrue);
    expect(offlineCapScale(t), greaterThan(1));
  });

  test('환생 직후(화물칸 작음) 8시간 복귀는 적어도 다음 강화 floorUpgrades번 값까지 싣는다(실기기 302골드·13.2K 잘림)', () {
    final h = EconomyHarness();
    final base = h.newGame().copyWith(
      crews: {
        'octo': const CrewState(level: 46),
        'manta': const CrewState(level: 31),
        'pang': const CrewState(level: 31),
      },
      progress: const Progress(stage: 5, bestStage: 60, rebirths: 1),
      savedAt: EconomyHarness.start.subtract(const Duration(hours: 8)),
    );
    final cap = goldCapacity(base, t);
    final floor = nextUpgradesCost(base, t, t.meta.raw.obj('offline').integer('floorUpgrades'));
    final s = sys.handle(base, const ClaimOffline(), h.ctx)!;
    final e = h.of<OfflineReward>().single;
    expect(floor > cap.times(3), isTrue, reason: '시험 전제: 환생 직후엔 바닥값이 용량 × 3보다 크다');
    expect(s.wallet.gold >= (e.gold < floor ? e.gold : floor), isTrue, reason: '다음 강화 몇 번은 할 수 있게');
  });
}

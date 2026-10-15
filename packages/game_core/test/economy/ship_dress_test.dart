import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 렌더 계약(S3 제안): BattleView.shipTierLook = max(지금 등급, 명예 등급) 그림, shipSkin, treasureSea.
void main() {
  final t = EconomyHarness.tables;
  final h = EconomyHarness();

  BattleView viewOf(GameState s) =>
      (CoreEngine(tables: t, clock: ManualClock(EconomyHarness.start), initial: s)..tick()).state.battle!;

  test('명예 등급이 높으면 등급 그림은 명예, 스킨·보물 바다를 그대로 싣는다', () {
    final tiers = t.shipTiers.tiers;
    final s = h.newGame().copyWith(
      progress: const Progress(treasureSea: 2),
      ship: ShipState(honorTier: tiers.length - 1, skin: 'storm', skinsOwned: const {'storm'}),
    );
    final v = viewOf(s);
    expect(v.shipTierLook, tiers.last.id);
    expect(v.shipSkin, 'storm');
    expect(v.treasureSea, 2);
  });

  test('기본(명예 0, 스킨 없음, 보통 바다): 지금 등급 그림, JSON에 skin·treasureSea 없음', () {
    final v = viewOf(h.newGame());
    expect(v.shipTierLook, t.shipTiers.tierAt(1).id);
    expect(v.shipSkin, isNull);
    final j = v.toJson();
    expect(j.containsKey('shipSkin') || j.containsKey('treasureSea'), isFalse);
    expect(BattleView.fromJson(j).shipTierLook, v.shipTierLook);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// ‘지금 할 수 있는 일’ 빨간 점 (설계서 4.9: 탭마다 하나, 눌러서 이득일 때만 · 계획 E5).
// 모두 경제 함수 결과를 bool로 select한다 — 상태는 20Hz로 바뀌지만 값(참/거짓)이 바뀔 때만 다시 그린다.

/// 상태 → 일괄 합치기로 레벨이 오르는 선원이 있나 (경제 `canMergeAny`).
final mergeAvailableProvider = Provider<bool Function(GameState state)>((ref) {
  final tables = ref.watch(tablesProvider);
  return (s) => canMergeAny(s, tables);
});

/// 배 탭: 살 수 있는 강화가 있다 (최대 레벨이 아니고 골드 ≥ 다음 비용).
final shipBadgeProvider = Provider<bool>((ref) {
  final parts = ref.watch(tablesProvider).shipParts.parts;
  return ref.watch(
    gameStateProvider.select(
      (s) => parts.any((p) {
        final lv = s.ship.parts[p.id] ?? 0;
        final max = p.maxLevel;
        return (max == null || lv < max) && s.wallet.gold >= partCost(p, lv);
      }),
    ),
  );
});

/// 선원 탭 할 일 수 (스킨 r2 숫자 뱃지): 승급할 수 있는 선원 + 쉬는 선원으로 채울 빈 출전 칸 + 일괄 합치기(있으면 1).
final crewBadgeCountProvider = Provider<int>((ref) {
  final tables = ref.watch(tablesProvider);
  final mergeable = ref.watch(mergeAvailableProvider);
  return ref.watch(
    gameStateProvider.select(
      (s) =>
          (mergeable(s) ? 1 : 0) +
          emptySlotCount(s, tables) +
          s.crews.keys.where((id) => promoteStatus(s, tables, id) == PromoteStatus.ok).length,
    ),
  );
});

/// 선원 탭 점: 할 일이 하나라도 있다.
final crewBadgeProvider = Provider<bool>((ref) => ref.watch(crewBadgeCountProvider) > 0);

/// 선원 탭 ‘일괄 합치기’ 버튼 점.
final mergeBadgeProvider = Provider<bool>((ref) {
  final mergeable = ref.watch(mergeAvailableProvider);
  return ref.watch(gameStateProvider.select(mergeable));
});

/// 소환 탭: 1회 소환할 젬이 있거나, 첫 10연 무료거나, 무료 소환 광고를 볼 수 있다.
final summonBadgeProvider = Provider<bool>((ref) {
  final tables = ref.watch(tablesProvider);
  final freeAd = ref.watch(adOfferProvider(AdPlacement.freeSummon));
  return freeAd ||
      ref.watch(gameStateProvider.select((s) => canSummon(s, tables, 1) || summonCostFor(s, tables, 10) == 0));
});

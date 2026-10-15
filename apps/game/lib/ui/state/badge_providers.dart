import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// ‘지금 할 수 있는 일’ 빨간 점 (설계서 4.9: 탭마다 하나, 눌러서 이득일 때만 · 계획 E5).
// 모두 경제 함수 결과를 bool로 select한다 — 상태는 20Hz로 바뀌지만 값(참/거짓)이 바뀔 때만 다시 그린다.

/// 상태 → 일괄 합치기로 레벨이 오르는 선원이 있나. 경제 `canMergeAny`가 오면 본문을 바꾼다(S2 요청 중). 기본 false.
final mergeAvailableProvider = Provider<bool Function(GameState state)>(
  (ref) =>
      (_) => false,
);

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

/// 선원 탭: 승급할 수 있는 선원, 일괄 합치기로 오를 선원, 또는 쉬는 선원으로 채울 빈 출전 칸(`emptySlotCount`)이 있다.
final crewBadgeProvider = Provider<bool>((ref) {
  final tables = ref.watch(tablesProvider);
  final mergeable = ref.watch(mergeAvailableProvider);
  return ref.watch(
    gameStateProvider.select(
      (s) =>
          mergeable(s) ||
          emptySlotCount(s, tables) > 0 ||
          s.crews.keys.any((id) => promoteStatus(s, tables, id) == PromoteStatus.ok),
    ),
  );
});

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

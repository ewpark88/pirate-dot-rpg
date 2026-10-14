import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 메타 화면 값은 경제 함수로만 구한다. provider로 감싸 둔 것은 테스트가 특정 화면 상태를 가짜로 만들기 위해서다.

/// 상태 → 다음 목표 (경제 `nextGoal`). null이면 막대를 숨긴다.
final nextGoalProvider = Provider<NextGoal? Function(GameState state)>((ref) {
  final tables = ref.watch(tablesProvider);
  return (s) => nextGoal(s, tables);
});

/// 상태 → 도감 보너스 (경제 `collectionBonus`). null이면 보너스 줄을 숨긴다.
final collectionBonusProvider = Provider<CollectionBonus? Function(GameState state)>((ref) {
  final tables = ref.watch(tablesProvider);
  return (s) => collectionBonus(s, tables);
});

/// 상태 → 떠 있는 보물상자의 기본 보상(골드, 경제 `chestReward`). null이면 금액을 숨긴다.
final chestRewardProvider = Provider<BigNum? Function(GameState state)>((ref) {
  final tables = ref.watch(tablesProvider);
  return (s) => chestReward(s, tables);
});

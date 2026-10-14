import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

/// 다음 목표 종류 (설계서 4.5).
enum GoalKind { shipTier, partMilestone, collection, rebirth }

/// 가장 가까운 목표 하나. [id]는 배 등급 id(shipTier)·부위 id(partMilestone), 나머지는 null.
@immutable
class GoalView {
  const GoalView({required this.kind, required this.remaining, required this.progress, this.id});

  final GoalKind kind;
  final String? id;

  /// 남은 스테이지·레벨·명 수.
  final int remaining;

  /// 0~1.
  final double progress;
}

/// 상태 → 다음 목표. null이면 막대를 숨긴다.
// TODO(economy): S2 nextGoal(B1)이 main에 오면 본문을 그 함수로. 그 전엔 숨김.
final nextGoalProvider = Provider<GoalView? Function(GameState state)>(
  (_) =>
      (_) => null,
);

/// 도감 보너스 (5명마다 공격력 +3%).
@immutable
class CollectionBonusView {
  const CollectionBonusView({required this.attackBonus, required this.nextIn});

  /// 지금 보너스 비율 (0.03 = 3%).
  final double attackBonus;

  /// 다음 보너스까지 남은 선원 수. 다 모았으면 0.
  final int nextIn;
}

/// 상태 → 도감 보너스. null이면 보너스 줄을 숨긴다.
// TODO(economy): S2 collectionBonus(B9)가 main에 오면 본문을 그 함수로. 그 전엔 숨김.
final collectionBonusProvider = Provider<CollectionBonusView? Function(GameState state)>(
  (_) =>
      (_) => null,
);

/// 상태 → 떠 있는 보물상자의 기본 보상(골드). null이면 금액을 숨긴다.
// TODO(economy): S2 chestReward(B3)가 main에 오면 본문을 그 함수로. 그 전엔 숨김.
final chestRewardProvider = Provider<BigNum? Function(GameState state)>(
  (_) =>
      (_) => null,
);

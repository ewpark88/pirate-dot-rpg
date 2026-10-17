import 'package:game_core/src/engine/state_parts.dart' show Json;
import 'package:meta/meta.dart';

// 업적 세이브(요청 docs/contracts/requests/ui-achievements.md 2절). 선택 키 `achievements` — 비면 본문에 없다(옛 세이브 그대로,
// 세이브 버전은 올리지 않는다). 진행 값은 세이브의 기존 누계(도감 처치·최고 스테이지·환생·소환 등)에서 계산하고,
// 세이브에 없던 누계(피버·필살기·러시 클리어·현상금 성공)만 [counts]에 센다.

@immutable
class AchievementState {
  const AchievementState({this.claimed = const {}, this.counts = const {}});

  factory AchievementState.fromJson(Json j) => AchievementState(
    claimed: (j['claimed'] as Map?)?.cast<String, int>() ?? const {},
    counts: (j['counts'] as Map?)?.cast<String, int>() ?? const {},
  );

  /// 업적 id → 받은 단계 수.
  final Map<String, int> claimed;

  /// 엔진이 세는 누계: fevers · ultimates · rushClears · bounties (achievements.json metric 이름).
  final Map<String, int> counts;

  bool get isEmpty => claimed.isEmpty && counts.isEmpty;
  int claimedOf(String id) => claimed[id] ?? 0;
  int count(String metric) => counts[metric] ?? 0;

  AchievementState copyWith({Map<String, int>? claimed, Map<String, int>? counts}) =>
      AchievementState(claimed: claimed ?? this.claimed, counts: counts ?? this.counts);

  Json toJson() => {if (claimed.isNotEmpty) 'claimed': claimed, if (counts.isNotEmpty) 'counts': counts};
}

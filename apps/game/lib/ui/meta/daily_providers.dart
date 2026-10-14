import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

/// 일일 퀘스트 한 줄 (설계서 4.5 매일, 사용자 결정 2026-10-14: 퀘스트마다 보상, 줄마다 받기).
/// [type]은 meta.json dailyQuests의 type(kill·upgrade·summon·ad).
@immutable
class QuestView {
  const QuestView({
    required this.id,
    required this.type,
    required this.progress,
    required this.target,
    required this.rewardGems,
    this.claimed = false,
  });

  final String id;
  final String type;
  final int progress;
  final int target;
  final int rewardGems;

  /// 오늘 이 퀘스트 보상을 받았나 (`daily.questsClaimed`).
  final bool claimed;

  bool get done => progress >= target;
  bool get canClaim => done && !claimed;
}

/// 출석 한 칸 보상. [ticket]이면 ‘영웅 이상 소환권’(7일차), 아니면 젬 [gems].
@immutable
class AttendanceReward {
  const AttendanceReward({this.gems = 0, this.ticket = false});

  final int gems;
  final bool ticket;
}

/// 출석 화면 값: 오늘이 몇 일차(1~7), 오늘 받았나, 칸별 보상.
@immutable
class AttendanceView {
  const AttendanceView({required this.day, required this.claimedToday, required this.rewards});

  final int day;
  final bool claimedToday;
  final List<AttendanceReward> rewards;

  bool get canClaim => !claimedToday;
}

/// 상태 → 일일 퀘스트. null이면 퀘스트 아이콘·시트를 숨긴다.
// TODO(economy): S2 dailyQuests·canClaimDaily(B7)가 main에 오면 본문을 그 함수로. 그 전엔 숨김.
final dailyQuestsProvider = Provider<List<QuestView>? Function(GameState state)>(
  (_) =>
      (_) => null,
);

/// 상태·지금 → 출석. null이면 출석 칸을 숨긴다.
// TODO(economy): S2 attendance(B8)가 main에 오면 본문을 그 함수로. 그 전엔 숨김.
final attendanceProvider = Provider<AttendanceView? Function(GameState state, DateTime now)>(
  (_) =>
      (_, _) => null,
);

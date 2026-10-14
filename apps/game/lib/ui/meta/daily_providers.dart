import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

/// 일일 퀘스트 한 줄 (설계서 4.5 매일). [type]은 meta.json dailyQuests의 type(kill·upgrade·summon·ad).
@immutable
class QuestView {
  const QuestView({required this.id, required this.type, required this.progress, required this.target});

  final String id;
  final String type;
  final int progress;
  final int target;

  bool get done => progress >= target;
}

/// 일일 퀘스트 화면 값: 4줄, 모두 달성 보상 젬, 받을 수 있나, 이미 받았나.
@immutable
class DailyQuestsView {
  const DailyQuestsView({
    required this.quests,
    required this.rewardGems,
    required this.canClaim,
    required this.claimed,
  });

  final List<QuestView> quests;
  final int rewardGems;
  final bool canClaim;
  final bool claimed;
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
final dailyQuestsProvider = Provider<DailyQuestsView? Function(GameState state)>(
  (_) =>
      (_) => null,
);

/// 상태·지금 → 출석. null이면 출석 칸을 숨긴다.
// TODO(economy): S2 attendance(B8)가 main에 오면 본문을 그 함수로. 그 전엔 숨김.
final attendanceProvider = Provider<AttendanceView? Function(GameState state, DateTime now)>(
  (_) =>
      (_, _) => null,
);

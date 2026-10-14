import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 상태 → 일일 퀘스트 (경제 `dailyQuests`, 사용자 결정: 퀘스트마다 보상·줄마다 받기). null이면 아이콘·시트를 숨긴다.
final dailyQuestsProvider = Provider<List<QuestView>? Function(GameState state)>((ref) {
  final tables = ref.watch(tablesProvider);
  return (s) => dailyQuests(s, tables);
});

/// 상태·지금 → 출석 (경제 `attendance`). null이면 출석 칸을 숨긴다.
final attendanceProvider = Provider<AttendanceView? Function(GameState state, DateTime now)>((ref) {
  final tables = ref.watch(tablesProvider);
  return (s, now) => attendance(s, tables, now);
});

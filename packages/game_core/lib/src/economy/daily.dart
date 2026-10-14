import 'dart:math' as math;

import 'package:game_core/src/economy/summon.dart';
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';
import 'package:game_data/game_data.dart';
import 'package:meta/meta.dart';

// 일일 초기화·퀘스트·출석 (설계서 4.5, 스펙 economy-m3-meta 규칙 4~6).

/// 기기 날짜가 바뀌었으면 일일 값을 초기화한다. 출석 일차는 유지(빠져도 초기화 없음).
GameState rollDay(GameState state, DateTime now) {
  final today = localDate(now);
  if (state.daily.date == today) return state;
  return state.copyWith(
    daily: DailyState(date: today, attendanceDay: state.daily.attendanceDay),
  );
}

/// [type](kill·upgrade·summon·ad) 퀘스트 진행을 [n]만큼 더한다. 목표에서 멈춘다.
/// 처치(kill)는 전투가 처치 직후 부른다(스펙 규칙 5).
GameState addQuestProgress(GameState state, GameTables t, String type, int n) {
  if (n <= 0) return state;
  final quests = {...state.daily.quests};
  var changed = false;
  for (final q in t.meta.dailyQuests.where((q) => q.str('type') == type)) {
    final id = q.str('id');
    final next = math.min((quests[id] ?? 0) + n, q.integer('target'));
    if (next != quests[id]) {
      quests[id] = next;
      changed = true;
    }
  }
  return changed ? state.copyWith(daily: _daily(state.daily, quests: quests)) : state;
}

/// 퀘스트 목록 화면용.
@immutable
class QuestView {
  const QuestView({
    required this.id,
    required this.type,
    required this.progress,
    required this.target,
    required this.claimed,
  });

  final String id;
  final String type;
  final int progress;
  final int target;
  final bool claimed;

  bool get done => progress >= target;
}

List<QuestView> dailyQuests(GameState state, GameTables t) => [
  for (final q in t.meta.dailyQuests)
    QuestView(
      id: q.str('id'),
      type: q.str('type'),
      progress: state.daily.quests[q.str('id')] ?? 0,
      target: q.integer('target'),
      claimed: state.daily.questsClaimed.contains(q.str('id')),
    ),
];

/// 끝났고 아직 안 받은 퀘스트가 있나.
bool canClaimDaily(GameState state, GameTables t) => dailyQuests(state, t).any((q) => q.done && !q.claimed);

/// 끝난 퀘스트마다 `dailyQuestRewardGems` (사용자 결정 ②). 받을 것이 없으면 상태 그대로.
GameState claimDaily(GameState state, ClaimDaily command, SystemContext ctx) {
  final t = ctx.tables;
  final ready = [
    for (final q in dailyQuests(state, t))
      if (q.done && !q.claimed) q.id,
  ];
  if (ready.isEmpty) return state;
  ctx.emit(SaveRequested(ctx.tick, reason: command.type));
  return state.copyWith(
    wallet: state.wallet.copyWith(gems: state.wallet.gems + ready.length * t.meta.dailyQuestRewardGems),
    daily: _daily(state.daily, questsClaimed: {...state.daily.questsClaimed, ...ready}),
  );
}

/// 출석 화면용. [day]는 다음에 받을(오늘 받았으면 오늘 받은) 일차 1~days.
@immutable
class AttendanceView {
  const AttendanceView({required this.day, required this.claimedToday, required this.rewards});

  final int day;
  final bool claimedToday;

  /// `meta.attendance.rewards` 그대로 (`gems` 또는 `summon`+`minRarity`).
  final List<JsonReader> rewards;
}

AttendanceView attendance(GameState state, GameTables t, DateTime now) {
  final a = t.meta.raw.obj('attendance');
  final claimedToday = state.daily.attendanceClaimed && state.daily.date == localDate(now);
  final last = state.daily.attendanceDay;
  return AttendanceView(
    day: claimedToday ? last : last % a.integer('days') + 1,
    claimedToday: claimedToday,
    rewards: a.objs('rewards'),
  );
}

/// 출석 받기 (사용자 결정 ③). 오늘 이미 받았으면 상태 그대로.
GameState claimAttendance(GameState state, ClaimAttendance command, SystemContext ctx) {
  final t = ctx.tables;
  final view = attendance(state, t, ctx.clock.now());
  if (view.claimedToday) return state;
  final reward = view.rewards[view.day - 1];
  var s = state.copyWith(daily: _daily(state.daily, attendanceDay: view.day, attendanceClaimed: true));
  if (reward.has('gems')) {
    s = s.copyWith(wallet: s.wallet.copyWith(gems: s.wallet.gems + reward.integer('gems')));
    ctx.emit(SaveRequested(ctx.tick, reason: command.type));
  }
  if (reward.has('summon')) {
    s = summonCards(s, ctx, reward.integer('summon'), reason: command.type, guarantee: reward.str('minRarity'));
  }
  return s;
}

DailyState _daily(
  DailyState d, {
  Map<String, int>? quests,
  Set<String>? questsClaimed,
  Map<String, int>? ads,
  int? attendanceDay,
  bool? attendanceClaimed,
}) => DailyState(
  date: d.date,
  ads: ads ?? d.ads,
  quests: quests ?? d.quests,
  attendanceDay: attendanceDay ?? d.attendanceDay,
  questsClaimed: questsClaimed ?? d.questsClaimed,
  attendanceClaimed: attendanceClaimed ?? d.attendanceClaimed,
);

/// 광고 장치 [placement]를 오늘 한 번 더 본 것으로 센다 (ads.dart가 쓴다).
GameState countAd(GameState state, GameTables t, String placement) {
  final s = state.copyWith(
    daily: _daily(state.daily, ads: {...state.daily.ads, placement: (state.daily.ads[placement] ?? 0) + 1}),
  );
  return addQuestProgress(s, t, 'ad', 1);
}

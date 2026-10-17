import 'package:game_core/src/economy/crew_stats.dart' show rarityOfLevel;
import 'package:game_core/src/economy/dex.dart' show dexCatalog;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

// 업적(요청 docs/contracts/requests/ui-achievements.md, 표 achievements.json): 업적마다 단계 여러 개 — 진행 값이 다음 단계 목표에
// 닿으면(lowerIsBetter면 이하) ClaimAchievement로 그 단계 젬. 진행 값은 세이브 누계에서 계산(achievementValue), 세이브에 없던
// 누계(피버·필살기·러시 클리어·현상금 성공)는 AchievementSystem이 이벤트를 보고 AchievementState.counts에 센다.

/// 화면 한 줄(요청 3절): 받은 단계 step/steps, 다음 목표·젬(다 받았으면 null), 지금 받을 수 있나.
typedef AchievementView = ({
  String id,
  String nameKey,
  String iconKey,
  int value,
  int step,
  int steps,
  int? nextTarget,
  int? nextGems,
  bool claimable,
  bool lowerIsBetter,
});

/// [metric]의 지금 값. 기록이 없는 짧을수록 좋은 값(러시 최고 기록)은 null.
int? achievementValue(GameState s, GameTables t, String metric) {
  int sumKills({required bool boss}) {
    final catalog = dexCatalog(t);
    return s.progress.dex.kills.entries.where((e) => catalog[e.key] == boss).fold(0, (a, e) => a + e.value);
  }

  return switch (metric) {
    'kills' => sumKills(boss: false),
    'bosses' => sumKills(boss: true),
    'bestStage' => s.progress.bestStage,
    'rebirths' => s.progress.rebirths,
    'collection' => s.collection.length,
    'mythicCrews' => s.crews.values.where((c) => rarityOfLevel(t.rarities, c.level).id == rarityOrder.last).length,
    'towerBest' => s.tower?.best ?? 0,
    'rushBestSec' => switch (s.rush?.bestTicks) {
      final int ticks => (ticks * t.waves.tickMs * secondsPerMillisecond).ceil(),
      _ => null,
    },
    'dungeonSteps' => (s.dungeon?.cleared.values ?? const <int>[]).fold<int>(0, (a, b) => a + b),
    'summons' => s.summonsTotal,
    'shipLevel' => s.ship.parts.values.fold<int>(0, (a, b) => a + b),
    _ => s.achievements.count(metric), // fevers · ultimates · rushClears · bounties
  };
}

bool _reached(AchievementDef a, int? value, int target) =>
    value != null && (a.lowerIsBetter ? value <= target : value >= target);

List<AchievementView> achievementsView(GameState s, GameTables t) => [
  for (final a in t.achievements.achievements)
    () {
      final value = achievementValue(s, t, a.metric);
      final step = s.achievements.claimedOf(a.id).clamp(0, a.steps.length);
      final next = step < a.steps.length ? a.steps[step] : null;
      return (
        id: a.id,
        nameKey: a.nameKey,
        iconKey: a.iconKey,
        value: value ?? 0,
        step: step,
        steps: a.steps.length,
        nextTarget: next?.target,
        nextGems: next?.gems,
        claimable: next != null && _reached(a, value, next.target),
        lowerIsBetter: a.lowerIsBetter,
      );
    }(),
];

/// 받을 수 있는 업적 수(빨간 점).
int achievementsClaimable(GameState s, GameTables t) => achievementsView(s, t).where((a) => a.claimable).length;

/// ClaimAchievement: 다음 단계에 닿았으면 젬 + 받은 단계 +1 + AchievementClaimed. 아니면 그대로.
GameState claimAchievement(GameState s, String id, SystemContext ctx) {
  final a = ctx.tables.achievements.byId(id);
  if (a == null) return s;
  final step = s.achievements.claimedOf(id);
  if (step >= a.steps.length) return s;
  final next = a.steps[step];
  if (!_reached(a, achievementValue(s, ctx.tables, a.metric), next.target)) return s;
  ctx
    ..emit(AchievementClaimed(ctx.tick, id: id, step: step + 1, gems: next.gems))
    ..emit(SaveRequested(ctx.tick, reason: 'achievement'));
  return s.copyWith(
    wallet: s.wallet.copyWith(gems: s.wallet.gems + next.gems),
    achievements: s.achievements.copyWith(claimed: {...s.achievements.claimed, id: step + 1}),
  );
}

/// 이번 틱 이벤트([events])에서 세이브에 없던 누계를 센다: 피버 시작·필살기·러시 5마리 클리어·현상금 성공.
GameState countAchievementEvents(GameState s, Iterable<GameEvent> events) {
  Map<String, int>? counts;
  void bump(String metric) => (counts ??= {...s.achievements.counts})[metric] = (counts![metric] ?? 0) + 1;
  for (final e in events) {
    switch (e) {
      case FeverStarted():
        bump('fevers');
      case UltimateCast():
        bump('ultimates');
      case RushEnded(reason: 'cleared'):
        bump('rushClears');
      case BountyCleared():
        bump('bounties');
      default:
    }
  }
  final c = counts;
  return c == null ? s : s.copyWith(achievements: s.achievements.copyWith(counts: c));
}

/// 업적 시스템: 명령 ClaimAchievement, 매 틱 이벤트 누계. 엔진 시스템 목록의 **맨 끝**(다른 시스템의 이벤트를 다 본 뒤).
class AchievementSystem implements GameSystem {
  const AchievementSystem();

  @override
  GameState? handle(GameState state, Command command, SystemContext ctx) =>
      command is ClaimAchievement ? claimAchievement(state, command.id, ctx) : null;

  @override
  GameState update(GameState state, SystemContext ctx) => countAchievementEvents(state, ctx.recent);
}

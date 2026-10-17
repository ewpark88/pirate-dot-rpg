import 'dart:convert';
import 'dart:io';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/achievements.dart' show countAchievementEvents;
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 업적(요청 docs/contracts/requests/ui-achievements.md · 표 achievements.json).
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11, 2, 3);
  final fresh = GameState.newGame(playerId: 'a', seed: 1, now: start);
  AchievementView row(GameState s, String id) => achievementsView(s, t).firstWhere((a) => a.id == id);

  test('표 15종 · 새 게임은 받은 단계 0, 최고 스테이지가 첫 목표에 닿으면 받을 수 있다(빨간 점 수)', () {
    expect(t.achievements.achievements, hasLength(15));
    final s = fresh.copyWith(clearTutorial: true);
    final stage = row(s, 'stage');
    expect((stage.step, stage.claimable), (0, false));
    final first = t.achievements.byId('stage')!.steps.first;
    final reached = s.copyWith(progress: s.progress.copyWith(bestStage: first.target));
    expect(row(reached, 'stage').claimable, isTrue);
    expect(achievementsClaimable(reached, t), greaterThanOrEqualTo(1));
  });

  test('ClaimAchievement: 닿았으면 젬 + 단계 +1 + AchievementClaimed, 다음 목표 전엔 무시 · JSON 왕복', () {
    final first = t.achievements.byId('stage')!.steps.first;
    final s0 = fresh.copyWith(clearTutorial: true);
    final s = s0.copyWith(progress: s0.progress.copyWith(bestStage: first.target));
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: s)
      ..tick()
      ..drainEvents();
    final gems = e.state.wallet.gems;
    e
      ..enqueue(const ClaimAchievement('stage'))
      ..tick();
    final ev = e.drainEvents().whereType<AchievementClaimed>().single;
    expect((ev.id, ev.step, ev.gems), ('stage', 1, first.gems));
    expect(e.state.wallet.gems, gems + first.gems);
    expect(e.state.achievements.claimedOf('stage'), 1);
    e
      ..enqueue(const ClaimAchievement('stage'))
      ..tick();
    expect(e.drainEvents().whereType<AchievementClaimed>(), isEmpty, reason: '다음 목표(40) 전');
    final back = GameState.fromJson(jsonDecode(jsonEncode(e.state.toJson())) as Map<String, dynamic>);
    expect(back.achievements.claimedOf('stage'), 1);
    expect(fresh.toJson().containsKey('achievements'), isFalse, reason: '비면 본문에 없다(옛 세이브 그대로)');
    for (final c in const <Command>[ClaimAchievement('kills')]) {
      expect(Command.fromJson(c.toJson()).toJson(), c.toJson());
    }
    const claimed = AchievementClaimed(4, id: 'kills', step: 2, gems: 20);
    expect(GameEvent.fromJson(claimed.toJson()).toJson(), claimed.toJson());
  });

  test('세이브에 없던 누계는 이벤트로 센다: 피버·필살기·러시 5마리 클리어(실패한 러시는 안 셈)', () {
    final s = countAchievementEvents(fresh, const [
      FeverStarted(1, untilTick: 9),
      FeverStarted(20, untilTick: 29),
      UltimateCast(3, crewId: 'pang', ultimateId: 'u'),
      RushEnded(5, killed: 5, ticks: 900, reason: 'cleared'),
      RushEnded(6, killed: 2, ticks: 400, reason: 'sunk'),
    ]);
    expect(s.achievements.counts, {'fevers': 2, 'ultimates': 1, 'rushClears': 1});
    expect(achievementValue(s, t, 'fevers'), 2);
    expect(identical(countAchievementEvents(s, const []), s), isTrue, reason: '이벤트 없으면 그대로');
  });

  test('실제 엔진: 피버가 시작되면 fevers 누계가 오른다(업적 시스템이 맨 끝에서 이번 틱 이벤트를 본다)', () {
    final s = GameState.fromJson(
      jsonDecode(File('../../fixtures/states/stage37_midgame.json').readAsStringSync()) as Map<String, dynamic>,
    ).copyWith(clearTutorial: true, savedAt: start);
    final e =
        CoreEngine(
            tables: t,
            clock: ManualClock(start),
            initial: s.copyWith(progress: s.progress.copyWith(fever: 0.99)),
          )
          ..enqueue(const OpSetInvincible(on: true))
          ..enqueue(const OpJumpStage(37));
    var fevers = 0;
    for (var i = 0; i < 600 && fevers == 0; i++) {
      e.tick();
      fevers += e.drainEvents().whereType<FeverStarted>().length;
    }
    expect(fevers, greaterThan(0));
    expect(e.state.achievements.count('fevers'), fevers);
  });

  test('러시 최고 기록은 짧을수록(lowerIsBetter): 기록 없으면 못 받고, 목표 초 이하면 받는다 · 처치·보스는 도감 누계', () {
    final fast = t.achievements.byId('rushFast')!;
    expect(fast.lowerIsBetter, isTrue);
    expect(row(fresh, 'rushFast').claimable, isFalse);
    final ticks = fast.steps.first.target * 1000 ~/ t.waves.tickMs;
    final s = fresh.copyWith(rush: RushState(bestTicks: ticks));
    expect(achievementValue(s, t, 'rushBestSec'), fast.steps.first.target);
    expect(row(s, 'rushFast').claimable, isTrue);
    final boss = t.regions.bosses.keys.first;
    final mob = t.regions.enemies.keys.first;
    final dex = fresh.copyWith(
      progress: fresh.progress.copyWith(dex: DexState(kills: {boss: 3, mob: 7})),
    );
    expect((achievementValue(dex, t, 'kills'), achievementValue(dex, t, 'bosses')), (7, 3));
  });
}

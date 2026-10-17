import 'dart:convert';
import 'dart:io';

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 요일 던전(docs/specs/platform-weekday-dungeon.md — S1 승인 2026-10-18).
void main() {
  final t = GameTables.load();
  final cfg = t.meta.raw.obj('dungeon');
  final start = DateTime.utc(2026, 11, 2, 3); // 월요일(관통 + 레이저)

  GameState fixture(String name) {
    final s = GameState.fromJson(
      jsonDecode(File('../../fixtures/states/$name.json').readAsStringSync()) as Map<String, dynamic>,
    ).copyWith(clearTutorial: true, savedAt: start);
    return s.copyWith(progress: s.progress.copyWith(rebirths: 1)); // 열림
  }

  ({CoreEngine e, ManualClock clock, List<GameEvent> events}) engine(GameState s) {
    final clock = ManualClock(start);
    return (e: CoreEngine(tables: t, clock: clock, initial: s), clock: clock, events: []);
  }

  void run(({CoreEngine e, ManualClock clock, List<GameEvent> events}) x, int ticks) {
    for (var i = 0; i < ticks; i++) {
      x.e.tick();
      x.events.addAll(x.e.drainEvents());
    }
  }

  void runDungeon(({CoreEngine e, ManualClock clock, List<GameEvent> events}) x, {int max = 3000}) {
    for (var i = 0; i < max && !x.events.any((e) => e is DungeonCleared || e is DungeonFailed); i++) {
      run(x, 1);
    }
  }

  test('요일 → 묶음: 월 관통+레이저 … 일 아무 계열, 출전은 그 계열 보유 선원만(파워 순, 출전 칸 수까지)', () {
    final s = fixture('all_crews_mythic');
    final mon = dungeonToday(s, t, start);
    expect(mon.str('id'), 'mon');
    final crews = dungeonCrews(s, t, mon);
    expect(crews, isNotEmpty);
    for (final id in crews) {
      expect(mon.strs('families'), contains(t.crews.byId(id).family));
    }
    final sun = dungeonGroupOn(t, DateTime.sunday);
    expect(sun.strs('families'), isEmpty);
    expect(dungeonCrews(s, t, sun).length, greaterThanOrEqualTo(crews.length));
  });

  test('신화 함대 1단계: 출전이 전장에서만 그 날 계열로 바뀌고 끝나면 원래대로(세이브 fleet 그대로), 계열 카드·젬, 깬 단계 기록', () {
    final x = engine(fixture('all_crews_mythic'));
    run(x, 1);
    final fleet = [...x.e.state.fleet];
    final tickets = x.e.state.dungeon!.tickets;
    final gems = x.e.state.wallet.gems;
    x.e.enqueue(const StartDungeon(1));
    run(x, 3);
    final started = x.events.whereType<DungeonStarted>().single;
    expect(x.e.state.fleet, fleet, reason: '세이브 편성은 그대로');
    expect(x.e.state.battle!.dungeon, isNotNull);
    runDungeon(x);
    final cleared = x.events.whereType<DungeonCleared>().single;
    expect(cleared.step, 1);
    expect(cleared.cards, hasLength(cfg.integer('cardsPerStep')));
    for (final id in cleared.cards) {
      expect(started.crewIds, contains(id), reason: '그 날 계열 선원 카드');
    }
    final dex = x.events.whereType<DexFirstKill>().fold(0, (a, d) => a + d.gems);
    expect(x.e.state.wallet.gems, gems + cleared.gems + dex);
    final d = x.e.state.dungeon!;
    expect(d.cleared['mon'], 1);
    expect(d.active, isNull);
    expect(d.tickets, tickets - 1);
    expect(x.e.state.battle!.dungeon, isNull);
  });

  test('열린 단계까지만(깬 단계 + 1) · 소탕은 깬 단계 이하만 바로 보상 · 그만두기·앱 종료는 도전 돌려줌', () {
    final x = engine(
      fixture('all_crews_mythic').copyWith(dungeon: const DungeonState(tickets: 3, refilledOn: '2026-11-02')),
    );
    run(x, 1);
    x.e.enqueue(const StartDungeon(3));
    run(x, 2);
    expect(x.e.state.dungeon!.active, isNull, reason: '3단계는 아직 안 열림');
    x.e.enqueue(const SweepDungeon(1));
    run(x, 1);
    expect(x.events.whereType<DungeonCleared>(), isEmpty, reason: '깬 단계가 없으면 소탕 못 함');
    x.e.enqueue(const StartDungeon(1));
    runDungeon(x);
    x.events.clear();
    final tickets = x.e.state.dungeon!.tickets;
    x.e.enqueue(const SweepDungeon(1));
    run(x, 1);
    expect(x.events.whereType<DungeonCleared>().single.swept, isTrue);
    expect(x.e.state.dungeon!.tickets, tickets - 1);
    x.e.enqueue(const GrantAdReward(AdPlacement.dungeonTicket));
    run(x, 1);
    x.e.enqueue(const StartDungeon(2));
    run(x, 20);
    final before = x.e.state.dungeon!.tickets;
    x.e.enqueue(const RetreatDungeon());
    run(x, 1);
    expect(x.events.whereType<DungeonFailed>().single.reason, 'retreat');
    expect(x.e.state.dungeon!.tickets, before + 1, reason: '실패는 도전 돌려줌');
    final saved = x.e.state.copyWith(
      dungeon: x.e.state.dungeon!.copyWith(active: const DungeonActive(group: 'mon', step: 1)),
    );
    final y = engine(saved);
    run(y, 2);
    expect(y.events.whereType<DungeonFailed>().single.reason, 'interrupted');
  });

  test('그 날 계열 선원이 없으면 입장 불가', () {
    final s = GameState.newGame(playerId: 'n', seed: 1, now: start);
    final open = s.copyWith(progress: s.progress.copyWith(rebirths: 1, bestStage: 60));
    final x = engine(open);
    run(x, 1);
    final crews = dungeonCrews(x.e.state, t, dungeonToday(x.e.state, t, start));
    expect(canStartDungeon(x.e.state, t, start, 1), crews.isNotEmpty);
  });

  test('묶음 hpMul: 선원 2명 계열이 낀 날(월)은 적이 가볍고, 끝나면 전장 배율이 1로 돌아온다', () {
    expect(dungeonGroupOn(t, DateTime.monday).number('hpMul'), lessThan(1));
    expect(dungeonGroupOn(t, DateTime.tuesday).number('hpMul'), 1);
  });

  test('결정론·JSON 왕복', () {
    String once() {
      final x = engine(fixture('all_crews_mythic'));
      run(x, 1);
      x.e.enqueue(const StartDungeon(1));
      runDungeon(x);
      return jsonEncode([for (final e in x.events) e.toJson()]);
    }

    expect(once(), once());
    const d = DungeonState(
      tickets: 2,
      refilledOn: '2026-11-02',
      adOn: '2026-11-02',
      cleared: {'mon': 3},
      active: DungeonActive(group: 'mon', step: 4),
    );
    expect(DungeonState.fromJson(d.toJson()).toJson(), d.toJson());
    const v = DungeonView(group: 'mon', step: 2, wave: 1, waves: 2);
    expect(DungeonView.fromJson(v.toJson()).toJson(), v.toJson());
    for (final e in const <GameEvent>[
      DungeonStarted(1, group: 'mon', step: 1, crewIds: ['a']),
      DungeonCleared(2, group: 'mon', step: 1, cards: ['a'], gems: 2, swept: true),
      DungeonFailed(3, group: 'mon', step: 2, reason: 'sunk'),
    ]) {
      expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson());
    }
    for (final c in const <Command>[StartDungeon(1), SweepDungeon(1), RetreatDungeon()]) {
      expect(Command.fromJson(c.toJson()).toJson(), c.toJson());
    }
  });
}

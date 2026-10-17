import 'dart:convert';
import 'dart:io';

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 보스 러시(docs/specs/platform-boss-rush.md — S1 승인 2026-10-18).
void main() {
  final t = GameTables.load();
  final cfg = t.meta.raw.obj('rush');
  final start = DateTime.utc(2026, 11, 4, 3); // 수요일 — 그 주 월요일 2026-11-02

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

  void runRush(({CoreEngine e, ManualClock clock, List<GameEvent> events}) x, {int max = 12000}) {
    for (var i = 0; i < max && !x.events.any((e) => e is RushEnded); i++) {
      run(x, 1);
    }
  }

  test('주간 조합: 같은 주는 같은 5마리(lineup 순서 — 대보스 마지막), 다음 주는 달라진다', () {
    final week = rushWeek(start);
    expect(week, '2026-11-02');
    final a = rushBosses(t, week);
    expect(a, hasLength(cfg.strs('lineup').length));
    expect(rushBosses(t, rushWeek(start.add(const Duration(days: 3)))), a, reason: '같은 주');
    expect(rushBosses(t, rushWeek(start.add(const Duration(days: 7)))), isNot(a), reason: '다음 주');
    expect(t.regions.bossClassOf(a.last), 'wall');
    for (final id in a) {
      expect(t.regions.bosses.containsKey(id), isTrue);
    }
  });

  test('열리면 이번 주 도전 weeklyTickets, 주가 바뀌면 다시 채우고 기록·구간을 비운다', () {
    final x = engine(fixture('stage37_midgame'));
    run(x, 1);
    expect(x.e.state.rush!.tickets, cfg.integer('weeklyTickets'));
    x.e.enqueue(const StartRush());
    runRush(x);
    expect(x.e.state.rush!.tickets, cfg.integer('weeklyTickets') - 1);
    x.clock.advance(const Duration(days: 7));
    run(x, 1);
    expect(x.e.state.rush!.tickets, cfg.integer('weeklyTickets'));
    expect(x.e.state.rush!.claimed, isEmpty);
    expect(x.e.state.rush!.bestTicks, isNull);
  });

  test('중반 함대: 차례로 잡다가 침몰하면 잡은 수 × perBossGems, 본 전투(같은 스테이지·골드 그대로)로', () {
    final x = engine(fixture('stage37_midgame'));
    run(x, 1);
    final stage = x.e.state.progress.stage;
    final gold = x.e.state.wallet.gold;
    final gems = x.e.state.wallet.gems;
    x.e.enqueue(const StartRush());
    runRush(x);
    final started = x.events.whereType<RushStarted>().single;
    final downs = x.events.whereType<RushBossDown>().toList();
    final ended = x.events.whereType<RushEnded>().single;
    expect([for (final d in downs) d.index], [for (var i = 0; i < downs.length; i++) i], reason: '차례로');
    expect([for (final d in downs) d.bossId], started.bosses.take(downs.length));
    expect(ended.killed, downs.length);
    expect(ended.reason, isIn(['sunk', 'cleared']));
    if (ended.reason == 'sunk') expect(ended.gems, downs.length * cfg.integer('perBossGems'));
    final dex = x.events.whereType<DexFirstKill>().fold(0, (a, d) => a + d.gems); // 처음 잡은 보스 도감 보상
    expect(x.e.state.wallet.gems, gems + ended.gems + dex);
    expect(x.e.state.progress.stage, stage);
    expect(x.e.state.wallet.gold, gold, reason: '러시는 골드 없음');
    expect(x.e.state.rush!.active, isNull);
    expect(x.e.state.battle!.rush, isNull);
  });

  test('신화 함대: 5마리 다 잡으면 기록 — 구간 보상은 주에 한 번, 최고 기록만 남는다', () {
    final x = engine(fixture('all_crews_mythic'));
    run(x, 1);
    x.e.enqueue(const StartRush());
    runRush(x);
    final first = x.events.whereType<RushEnded>().single;
    expect(first.reason, 'cleared');
    expect(first.killed, cfg.strs('lineup').length);
    expect(first.best, isTrue);
    expect(x.e.state.rush!.bestTicks, first.ticks);
    final claimed = x.e.state.rush!.claimed;
    expect(claimed, isNotEmpty, reason: '신화 함대는 구간 안에 깬다');
    x.events.clear();
    x.e.enqueue(const StartRush());
    runRush(x);
    final again = x.events.whereType<RushEnded>().single;
    expect(again.gems, again.killed * cfg.integer('perBossGems') + _newBrackets(cfg, claimed, again.ticks, t));
    expect(x.e.state.rush!.bestTicks, again.ticks < first.ticks ? again.ticks : first.ticks);
  });

  test('그만두기·앱 종료(interrupted)·광고 도전 +1', () {
    final x = engine(fixture('stage37_midgame'));
    run(x, 1);
    x.e.enqueue(const StartRush());
    run(x, 40);
    x.e.enqueue(const RetreatRush());
    run(x, 1);
    expect(x.events.whereType<RushEnded>().single.reason, 'retreat');
    final saved = x.e.state.copyWith(
      rush: x.e.state.rush!.copyWith(active: const RushActive(index: 2, ticks: 900)),
    );
    final y = engine(saved);
    run(y, 2);
    final cut = y.events.whereType<RushEnded>().single;
    expect(cut.reason, 'interrupted');
    expect(cut.killed, 2);
    expect(cut.gems, 2 * cfg.integer('perBossGems'));
    final before = y.e.state.rush!.tickets;
    y.e.enqueue(const GrantAdReward(AdPlacement.rushTicket));
    run(y, 1);
    expect(y.e.state.rush!.tickets, before + 1);
  });

  test('러시·탑·현상금은 한 번에 하나만', () {
    final x = engine(fixture('stage37_midgame'));
    run(x, 1);
    x.e.enqueue(const StartRush());
    run(x, 2);
    final towerTickets = x.e.state.tower!.tickets;
    x.e.enqueue(const StartTower());
    run(x, 2);
    expect(x.e.state.tower!.tickets, towerTickets);
    expect(x.e.state.tower!.active, isNull);
  });

  test('저장 형식: RushState·RushView·이벤트·명령 JSON 왕복', () {
    const r = RushState(
      week: '2026-11-02',
      tickets: 5,
      adOn: '2026-11-03',
      bestTicks: 2400,
      claimed: [0, 1],
      active: RushActive(index: 3, ticks: 800),
    );
    expect(RushState.fromJson(r.toJson()).toJson(), r.toJson());
    const v = RushView(index: 2, total: 5, ticks: 600);
    expect(RushView.fromJson(v.toJson()).toJson(), v.toJson());
    for (final e in const <GameEvent>[
      RushStarted(1, bosses: ['a', 'b']),
      RushBossDown(2, index: 0, bossId: 'a', ticks: 300),
      RushEnded(3, killed: 5, ticks: 2400, reason: 'cleared', gems: 115, pieces: 15, best: true),
    ]) {
      expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson());
    }
    for (final c in const <Command>[StartRush(), RetreatRush()]) {
      expect(Command.fromJson(c.toJson()).toJson(), c.toJson());
    }
  });
}

/// [claimed] 밖이고 [ticks] 안에 든 구간 젬 합(두 번째 도전에서 새로 받는 것).
int _newBrackets(JsonReader cfg, List<int> claimed, int ticks, GameTables t) {
  final perSec = Duration.millisecondsPerSecond / t.waves.tickMs;
  var gems = 0;
  final b = cfg.objs('brackets');
  for (var i = 0; i < b.length; i++) {
    if (!claimed.contains(i) && ticks <= b[i].number('sec') * perSec) gems += b[i].integer('gems');
  }
  return gems;
}

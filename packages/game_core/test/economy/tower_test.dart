import 'dart:convert';
import 'dart:io';

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 심연의 탑(docs/specs/platform-content-v2.md 4절, 계약 platform-tower.md — S1 승인 2026-10-18).
void main() {
  final t = GameTables.load();
  final cfg = t.meta.raw.obj('tower');
  final start = DateTime.utc(2026, 11, 2, 3); // 현지 날짜가 분명한 시각

  GameState fixture(String name) => GameState.fromJson(
    jsonDecode(File('../../fixtures/states/$name.json').readAsStringSync()) as Map<String, dynamic>,
  ).copyWith(clearTutorial: true);

  // 중반 함대(스테이지 37 샘플) + 환생 1 = 탑 열림 — 5~6층에서 가라앉는다(신화 함대는 배가 안 맞아 끝나지 않음).
  GameState mid() {
    final s = fixture('stage37_midgame');
    return s.copyWith(progress: s.progress.copyWith(rebirths: 1));
  }

  ({CoreEngine e, ManualClock clock, List<GameEvent> events}) engine(GameState s) {
    final clock = ManualClock(start);
    return (
      e: CoreEngine(
        tables: t,
        clock: clock,
        initial: s.copyWith(savedAt: start),
      ),
      clock: clock,
      events: [],
    );
  }

  void run(({CoreEngine e, ManualClock clock, List<GameEvent> events}) x, int ticks) {
    for (var i = 0; i < ticks; i++) {
      x.e.tick();
      x.events.addAll(x.e.drainEvents());
    }
  }

  /// 탑이 끝날 때까지(최대 [max]틱) — 끝난 틱에서 멈춰 본 전투가 이어지기 전 상태를 본다.
  void runTower(({CoreEngine e, ManualClock clock, List<GameEvent> events}) x, {int max = 9000}) {
    for (var i = 0; i < max && !x.events.any((e) => e is TowerEnded); i++) {
      run(x, 1);
    }
  }

  test('열림: 최고 스테이지 unlockStage 또는 환생 1 — 그 전엔 상태 없음, 열리면 도전권 ticketsPerDay', () {
    final closed = engine(GameState.newGame(playerId: 'a', seed: 1, now: start));
    run(closed, 2);
    expect(closed.e.state.tower, isNull);
    final open = engine(
      fixture('stage37_midgame').copyWith(progress: fixture('stage37_midgame').progress.copyWith(rebirths: 1)),
    );
    run(open, 2);
    expect(open.e.state.tower!.tickets, cfg.integer('ticketsPerDay'));
  });

  test('도전권은 날마다 쌓이고 maxTickets에서 멈춘다(매일 안 들어와도 됨)', () {
    final x = engine(mid());
    run(x, 1);
    x.clock.advance(const Duration(days: 10));
    run(x, 1);
    expect(x.e.state.tower!.tickets, cfg.integer('maxTickets'));
  });

  test('도전 → 층 진행 → 침몰하면 끝: 도달 층 상자·최고 층 기록, 본 전투(같은 스테이지)로 돌아옴, 도전권 −1', () {
    final x = engine(mid());
    run(x, 1);
    final stage = x.e.state.progress.stage;
    final gold = x.e.state.wallet.gold;
    final tickets = x.e.state.tower!.tickets;
    x.e.enqueue(const StartTower());
    runTower(x);
    final ended = x.events.whereType<TowerEnded>().toList();
    expect(x.events.whereType<TowerStarted>(), hasLength(1));
    expect(ended, hasLength(1), reason: '배가 언젠가 가라앉는다(층마다 적이 늘고 강해짐)');
    expect(ended.single.reason, 'sunk');
    final cleared = x.events.whereType<TowerFloorCleared>().toList();
    expect(cleared, isNotEmpty);
    expect([for (final c in cleared) c.floor], [for (var i = 1; i <= cleared.length; i++) i], reason: '1층부터 차례로');
    expect(ended.single.floor, cleared.last.floor);
    final w = x.e.state.tower!;
    expect(w.active, isNull);
    expect(w.best, cleared.last.floor);
    expect(w.firstCleared, cleared.last.floor);
    expect(w.tickets, tickets - 1);
    expect(x.e.state.progress.stage, stage, reason: '본 진행 그대로');
    expect(x.e.state.wallet.gold, gold, reason: '탑은 골드 없음');
    expect(x.e.state.battle!.tower, isNull);
    // 첫 클리어 보상: 층마다 firstGems, cardEvery층마다 카드 1.
    expect(cleared.first.gems, cfg.integer('firstGems'));
    for (final c in cleared) {
      expect(c.cards, c.floor % cfg.integer('cardEvery') == 0 ? 1 : 0);
    }
  });

  test('첫 클리어 보상은 한 번만 — 두 번째 도전에서 같은 층은 0', () {
    final x = engine(mid());
    run(x, 1);
    x.e.enqueue(const OpSetBountyTickets(0)); // 관계없음 — 현상금과 따로
    x.e.enqueue(const StartTower());
    runTower(x);
    final firstBest = x.e.state.tower!.firstCleared;
    x.events.clear();
    x.clock.advance(const Duration(days: 1));
    run(x, 1);
    x.e.enqueue(const StartTower());
    runTower(x);
    final again = x.events.whereType<TowerFloorCleared>().where((c) => c.floor <= firstBest);
    expect(again, isNotEmpty);
    expect(again.every((c) => c.gems == 0 && c.cards == 0), isTrue);
  });

  test('소탕: 최고 층 × sweepRatio 상자, 첫 클리어 없음, 도전권 −1 — 기록이 없으면 무시', () {
    final x = engine(mid());
    run(x, 1);
    x.e.enqueue(const SweepTower());
    run(x, 1);
    expect(x.events.whereType<TowerSwept>(), isEmpty, reason: '깬 층이 없다');
    x.e.enqueue(const StartTower());
    runTower(x);
    x.clock.advance(const Duration(days: 1));
    run(x, 1);
    final best = x.e.state.tower!.best;
    final tickets = x.e.state.tower!.tickets;
    final gems = x.e.state.wallet.gems;
    x.e.enqueue(const SweepTower());
    run(x, 1);
    final swept = x.events.whereType<TowerSwept>().single;
    expect(swept.floor, (best * cfg.number('sweepRatio')).floor().clamp(1, best));
    expect(x.e.state.wallet.gems, gems + swept.chestGems);
    expect(x.e.state.tower!.tickets, tickets - 1);
  });

  test('앱이 꺼져 진행 중 탑이 세이브에 남으면: 불러온 첫 틱에 끝(interrupted) — 도전권은 돌려주지 않음', () {
    final s = mid();
    final saved = s.copyWith(
      tower: const TowerState(
        tickets: 1,
        refilledOn: '2026-11-02',
        best: 3,
        firstCleared: 3,
        active: TowerActive(floor: 5),
      ),
    );
    final x = engine(saved);
    run(x, 2);
    final ended = x.events.whereType<TowerEnded>().single;
    expect(ended.reason, 'interrupted');
    expect(ended.floor, 4);
    expect(x.e.state.tower!.active, isNull);
    expect(x.e.state.tower!.tickets, 1);
    expect(x.e.state.tower!.best, 4);
  });

  test('그만두기: 끝(retreat) · 광고 도전권 +1(하루 1, 상한을 넘어도)', () {
    final x = engine(mid());
    run(x, 1);
    x.e.enqueue(const StartTower());
    run(x, 600);
    x.e.enqueue(const RetreatTower());
    run(x, 1);
    expect(x.events.whereType<TowerEnded>().single.reason, 'retreat');
    expect(x.e.state.tower!.active, isNull);
    final before = x.e.state.tower!.tickets;
    x.e.enqueue(const GrantAdReward(AdPlacement.towerTicket));
    run(x, 1);
    expect(x.e.state.tower!.tickets, before + 1);
    x.e.enqueue(const GrantAdReward(AdPlacement.towerTicket));
    run(x, 1);
    expect(x.e.state.tower!.tickets, before + 1, reason: '하루 1');
  });

  test('안전판: 한 층이 floorTimeLimitSec를 넘으면 그 층까지 기록하고 끝(timeout)', () {
    final raw = Map<String, String>.of(rawTables);
    final meta = jsonDecode(raw['meta']!) as Map<String, dynamic>;
    (meta['tower'] as Map<String, dynamic>)['floorTimeLimitSec'] = 1;
    raw['meta'] = jsonEncode(meta);
    final clock = ManualClock(start);
    final e =
        CoreEngine(
            tables: GameTables.load(raw),
            clock: clock,
            initial: mid().copyWith(savedAt: start),
          )
          ..tick()
          ..enqueue(const StartTower());
    final events = <GameEvent>[];
    for (var i = 0; i < 200 && !events.any((x) => x is TowerEnded); i++) {
      e.tick();
      events.addAll(e.drainEvents());
    }
    final ended = events.whereType<TowerEnded>().single;
    expect(ended.reason, 'timeout');
    expect(ended.floor, 0);
    expect(e.state.tower!.active, isNull);
  });

  test('결정론: 같은 상태·같은 명령이면 같은 탑', () {
    String once() {
      final x = engine(mid());
      run(x, 1);
      x.e.enqueue(const StartTower());
      run(x, 1500);
      return jsonEncode([for (final e in x.events) e.toJson()]);
    }

    expect(once(), once());
  });

  test('저장 형식: TowerState·BattleView.tower·이벤트·명령 JSON 왕복', () {
    const w = TowerState(
      tickets: 2,
      refilledOn: '2026-11-02',
      adOn: '2026-11-01',
      best: 7,
      firstCleared: 7,
      active: TowerActive(floor: 8),
    );
    expect(TowerState.fromJson(w.toJson()).toJson(), w.toJson());
    const v = TowerView(floor: 3, wave: 2, waves: 3);
    expect(TowerView.fromJson(v.toJson()).toJson(), v.toJson());
    for (final e in const <GameEvent>[
      TowerStarted(1, floor: 1),
      TowerFloorCleared(2, floor: 5, gems: 10, cards: 1),
      TowerEnded(3, floor: 4, reason: 'sunk', kills: 99, chestGems: 20),
      TowerSwept(4, floor: 3, chestGems: 20),
    ]) {
      expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson());
    }
    for (final c in const <Command>[StartTower(), SweepTower(), RetreatTower()]) {
      expect(Command.fromJson(c.toJson()).toJson(), c.toJson());
    }
  });
}

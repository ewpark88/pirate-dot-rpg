import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 항해 돌발 이벤트 (docs/specs/platform-fun-sea-events.md 수용 기준 1~5).
void main() {
  final t = EconomyHarness.tables;
  final cfg = t.meta.raw.obj('seaEvents');
  final tickSec = t.waves.tickMs / 1000;

  GameState start({int stage = 20}) =>
      GameState.newGame(
        playerId: 's',
        seed: 5,
        now: EconomyHarness.start,
        crews: t.meta.startingCrews,
      ).copyWith(
        progress: Progress(stage: stage, bestStage: stage),
        clearTutorial: true,
      );

  CoreEngine engine(GameState s) => CoreEngine(tables: t, clock: ManualClock(EconomyHarness.start), initial: s);

  List<GameEvent> run(CoreEngine e, double sec) {
    final out = <GameEvent>[];
    for (var i = 0; i < (sec / tickSec).round(); i++) {
      e.tick();
      out.addAll(e.drainEvents());
    }
    return out;
  }

  test('기준 1: 같은 시드면 이벤트 순서·시각이 같고, 같은 이벤트가 연속하지 않으며, 끝난 뒤 다음까지 60초 이상', () {
    List<(int, String)> starts() => [
      for (final ev in run(engine(start()), 600))
        if (ev is SeaEventStarted) (ev.tick, ev.id),
    ];
    final a = starts();
    expect(a, starts());
    expect(a.length, greaterThanOrEqualTo(3));
    for (var i = 1; i < a.length; i++) {
      expect(a[i].$2, isNot(a[i - 1].$2));
    }
    final ends = <int>[];
    final all = run(engine(start()), 600);
    for (final ev in all) {
      if (ev is SeaEventEnded) ends.add(ev.tick);
    }
    final st = [
      for (final ev in all)
        if (ev is SeaEventStarted) ev.tick,
    ];
    for (var i = 1; i < st.length; i++) {
      final prevEnd = ends.lastWhere((x) => x <= st[i]);
      expect(
        (st[i] - prevEnd) * tickSec,
        greaterThanOrEqualTo(((cfg.raw['intervalSec'] as List).first as num) - tickSec),
      );
    }
  });

  test('minStage 미만이면 일어나지 않는다', () {
    expect(run(engine(start(stage: cfg.integer('minStage') - 1)), 300).whereType<SeaEventStarted>(), isEmpty);
  });

  test('기준 2: 보스전 중이면 보스전이 끝난 뒤 시작', () {
    final e = engine(start().copyWith(progress: const Progress(stage: 20, bestStage: 20, seaEventInSec: 0.5)))
      ..enqueue(const OpSpawnBoss());
    final events = run(e, 2);
    expect(events.whereType<SeaEventStarted>(), isEmpty, reason: '보스 중');
  });

  test('기준 3: 황금 물고기 3마리 탭 → 3마리 골드, 남은 마리의 autoCatchRatio(내림)는 끝날 때 자동', () {
    final e = engine(start())..enqueue(const OpSeaEvent('goldfish'));
    run(e, tickSec);
    final fish = e.state.battle!.enemies.where((x) => x.eventKind == 'goldfish').toList();
    expect(fish.length, inInclusiveRange(8, 12));
    final gold0 = e.state.wallet.gold;
    for (final f in fish.take(3)) {
      e.enqueue(TapSeaEvent(f.id));
    }
    final events = run(e, cfg.objs('events').first.number('durationSec') + 1);
    final caught = events.whereType<GoldfishCaught>().toList();
    expect(caught.where((c) => !c.auto), hasLength(3));
    expect(caught.where((c) => c.auto), hasLength(((fish.length - 3) * 0.3).floor()));
    expect(e.state.wallet.gold > gold0, isTrue);
    expect(e.state.battle!.enemies.where((x) => x.eventKind == 'goldfish'), isEmpty);
    expect(events.whereType<SeaEventEnded>().single.id, 'goldfish');
  });

  test('기준 4: 보물 상선을 시간 안에 못 잡으면 떠남, 보상 0, 스테이지·파 그대로', () {
    final s0 = start(stage: 400); // 상선이 아주 단단해 못 잡는다
    final e = engine(s0)
      ..enqueue(const OpSetInvincible(on: true))
      ..enqueue(const OpSeaEvent('merchant'));
    run(e, tickSec);
    final gems0 = e.state.wallet.gems;
    final stage0 = e.state.progress.stage;
    final events = run(e, 21);
    expect(events.whereType<SeaEventEnded>().single.result, 'left');
    expect(e.state.wallet.gems, gems0);
    expect(e.state.progress.stage, stage0);
    expect(e.state.battle!.enemies.where((x) => x.eventKind == 'merchant'), isEmpty);
  });

  test('보물 상선은 화면 옆 밖에서 시작해 배 둘레 + passMargin 밖 가로선으로 지나간다 (배 위를 지나지 않음)', () {
    final top = t.waves.raw.obj('top');
    final m = cfg.objs('events').firstWhere((x) => x.str('id') == 'merchant');
    for (var seed = 0; seed < 8; seed++) {
      final e = engine(start().copyWith(rngSeed: seed))..enqueue(const OpSeaEvent('merchant'));
      run(e, tickSec);
      final ship = e.state.battle!.enemies.singleWhere((x) => x.eventKind == 'merchant');
      expect(
        (ship.y - top.number('shipY')).abs(),
        greaterThanOrEqualTo(top.number('shipRadius') + m.number('passMargin') - 1),
      );
      expect((ship.x - top.number('shipX')).abs(), greaterThan(top.number('viewWidth') / 2));
    }
  });

  test('보물 상선을 잡으면 젬 + 보유 선원 카드', () {
    final e = engine(
      start(
        stage: 6,
      ).copyWith(ship: const ShipState(parts: {'cannon': 200, 'hull': 200, 'sail': 30, 'crowsnest': 45, 'cargo': 0})),
    )..enqueue(const OpSeaEvent('merchant'));
    final gems0 = e.state.wallet.gems;
    final events = run(e, 21);
    expect(events.whereType<SeaEventEnded>().single.result, 'done');
    expect(e.state.wallet.gems, greaterThanOrEqualTo(gems0 + cfg.objs('events')[1].integer('gems')));
  });

  test('기준 5: 유리병을 10초 동안 안 고르면 첫 쪽지(골드) 자동, PickBottle(1)이면 순풍', () {
    final e = engine(start())..enqueue(const OpSeaEvent('bottle'));
    final opened = run(e, tickSec).whereType<BottleOpened>().single;
    expect(opened.choices, ['gold', 'tailwind', 'gift']);
    expect(e.state.battle!.seaEvent!.choices, opened.choices);
    final gold0 = e.state.wallet.gold;
    final events = run(e, 11);
    final picked = events.whereType<BottlePicked>().single;
    expect([picked.index, picked.auto], [0, true]);
    expect(e.state.wallet.gold > gold0, isTrue);

    final e2 = engine(start())..enqueue(const OpSeaEvent('bottle'));
    run(e2, tickSec);
    e2.enqueue(const PickBottle(1));
    final p2 = run(e2, tickSec).whereType<BottlePicked>().single;
    expect([p2.index, p2.auto], [1, false]);
    expect(e2.state.buffs.tailwindUntil, isNotNull);
  });

  test('폭풍 중 처치 골드 × goldMultiplier', () {
    final e = engine(start())..enqueue(const OpSeaEvent('storm'));
    run(e, tickSec);
    expect(e.state.battle!.seaEvent!.id, 'storm');
    expect(stormGoldMultiplier(e.state, t), cfg.objs('events').last.number('goldMultiplier'));
  });
}

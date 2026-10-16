import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/fast_sail.dart' show resupply;
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 빠른 항해 돌파 (docs/specs/platform-fast-sail-breakthrough.md 수용 기준 1~3·5).
void main() {
  final start = DateTime.utc(2026, 11);

  GameTables withBreak({bool on = true}) {
    final raw = Map<String, String>.of(rawTables);
    final waves = jsonDecode(raw['waves']!) as Map<String, dynamic>;
    final rs = waves['rebirthSkip'] as Map<String, dynamic>;
    if (on) {
      rs
        ..['fraction'] =
            0.55 // 구간 길이를 고정(S2가 표를 바꿔도 리듬 단계를 다 본다)
        ..['breakSec'] = 2.0
        ..['travelSec'] = 0.3
        ..['breakAccel'] = 0.75
        ..['breakMinSec'] = 0.25
        ..['finaleSec'] = 0.6;
    } else {
      ['breakSec', 'travelSec', 'breakAccel', 'breakMinSec', 'finaleSec'].forEach(rs.remove);
    }
    raw['waves'] = jsonEncode(waves);
    return GameTables.load(raw);
  }

  GameState reborn() => GameState.newGame(playerId: 'f', seed: 9, now: start).copyWith(
    progress: const Progress(stage: 10, bestStage: 60, rebirths: 1),
    crews: const {'octo': CrewState()},
  );

  ({List<GameEvent> events, GameState state, int ticks}) run(GameTables t, double seconds) {
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: reborn());
    final events = <GameEvent>[];
    var ticks = 0;
    for (; ticks < (seconds * 1000 / t.waves.tickMs).round(); ticks++) {
      e.tick();
      events.addAll(e.drainEvents());
      if (events.whereType<FastSailEnded>().isNotEmpty) break;
    }
    return (events: events, state: e.state, ticks: ticks);
  }

  test('구간: 시작·끝 한 번씩, from·to = 범위, 보스마다 BreakthroughStrike(연속 수), 리듬 build → rush → finale', () {
    final t = withBreak();
    final to = (60 * t.waves.rebirthSkip.fraction).ceil();
    final r = run(t, 60);
    final started = r.events.whereType<FastSailStarted>().single;
    expect((started.from, started.to), (10, to));
    final strikes = r.events.whereType<BreakthroughStrike>().toList();
    expect(strikes.map((e) => e.combo), [for (var i = 1; i <= to - 10 + 1; i++) i]);
    expect(strikes.first.stage, 10);
    final ended = r.events.whereType<FastSailEnded>().single;
    expect((ended.from, ended.to, ended.stages, ended.skipped), (10, to, to - 10 + 1, false));
    expect(r.state.progress.stage, to + 1);
    // 리듬 가속(사용자 지시): 2.0초 × 0.75ⁿ, 최소 0.25초 + 이동(같은 비율), 마지막 0.6초 — 13스테이지 합 ≈ 2+1.5+1.13+0.84+0.63+0.47+0.36+0.27+0.25×4+0.6 + 이동
    final secs = r.ticks * t.waves.tickMs / 1000;
    expect(secs / ended.stages, lessThan(0.8), reason: '점점 빨라져 순식간에(스테이지당 평균)');
    final gaps = [for (var i = 1; i < strikes.length; i++) strikes[i].tick - strikes[i - 1].tick];
    expect(gaps.first, greaterThan(gaps[gaps.length - 2] * 3), reason: '처음보다 훨씬 빠르게');
    expect(strikes.map((e) => e.phase).toSet(), {'build', 'rush', 'finale'});
    expect(strikes.last.phase, 'finale');
    expect(strikes.first.speed, 1);
    expect(strikes[strikes.length - 2].speed, closeTo(2.0 / 0.25, 1e-9));
    expect(gaps.last, greaterThan(gaps[gaps.length - 2]), reason: '마지막은 0.6초 슬로모션');
  });

  test('보상: 요약 = 그동안 받은 것(골드 > 0, 젬 = 보스 처치 젬 합), 돌파 중 피버 게이지 멈춤, BattleView.fastSail', () {
    final r = run(withBreak(), 60);
    final ended = r.events.whereType<FastSailEnded>().single;
    expect(ended.gold.toDouble(), greaterThan(0));
    // 환생 직후 화물칸이 작아 대부분 넘친다(S2) — 실은 양 + 넘친 양 = 번 골드, 넘친 양을 따로 싣는다.
    expect(ended.lost.toDouble(), greaterThan(0), reason: '화물칸 Lv0이면 넘친다');
    expect(ended.gems, r.events.whereType<BossCleared>().fold<int>(0, (a, e) => a + e.gems));
    expect(r.events.whereType<FeverStarted>(), isEmpty);
    expect(r.state.progress.fever, 0, reason: '돌파 동안 게이지가 오르지 않는다');
    expect(r.state.battle!.fastSail, isNull, reason: '끝나면 키 없음');
  });

  test('구간 중에는 BattleView.fastSail {from, to, combo}', () {
    final t = withBreak();
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: reborn())..advance(100);
    final v = e.state.battle!.fastSail!;
    expect(v.from, 10);
    expect(v.combo, greaterThan(0));
  });

  test('표에 breakSec 없음 = 지금처럼(돌파 이벤트 없음), 같은 시드는 같다', () {
    final r = run(withBreak(on: false), 10);
    expect(r.events.whereType<FastSailStarted>(), isEmpty);
    expect(r.events.whereType<BreakthroughStrike>(), isEmpty);
    String json(GameTables t) => run(t, 20).events.map((e) => e.toJson()).join();
    expect(json(withBreak()), json(withBreak()));
  });

  test('건너뛰기 = 끝까지 돈 것과 같은 스테이지·젬, 골드도 같다(±1%) — FastSailEnded skipped', () {
    final t = withBreak();
    final full = run(t, 60);
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: reborn())
      ..advance(10)
      ..drainEvents();
    final before = e.state.wallet;
    e
      ..enqueue(const SkipFastSail())
      ..tick();
    final events = e.drainEvents();
    final ended = events.whereType<FastSailEnded>().single;
    expect(ended.skipped, isTrue);
    expect(e.state.progress.stage, full.state.progress.stage);
    expect(e.state.wallet.gems, full.state.wallet.gems);
    final skipGold = e.state.wallet.gold.toDouble();
    expect(skipGold, closeTo(full.state.wallet.gold.toDouble(), full.state.wallet.gold.toDouble() * 0.01));
    expect(e.state.battle!.fastSail, isNull);
    final total = full.events.whereType<FastSailEnded>().single;
    expect(
      ended.gold.toDouble() + ended.lost.toDouble(),
      closeTo(total.gold.toDouble() + total.lost.toDouble(), (total.gold.toDouble() + total.lost.toDouble()) * 0.01),
      reason: '번 골드(실은 + 넘친)도 같다',
    );
    expect(before.gold.toDouble(), lessThan(skipGold));
  });

  test('구간이 아니면 건너뛰기는 아무것도 안 한다', () {
    final e = CoreEngine(
      tables: withBreak(),
      clock: ManualClock(start),
      initial: reborn().copyWith(progress: const Progress(stage: 30, bestStage: 40, rebirths: 1)),
    )..advance(5);
    final stage = e.state.progress.stage;
    e
      ..enqueue(const SkipFastSail())
      ..tick();
    expect(e.drainEvents().whereType<FastSailEnded>(), isEmpty);
    expect(e.state.progress.stage, stage);
  });

  group('보급(사용자 실기기 — 빠른 항해 뒤 배 레벨이 없어 침몰)', () {
    final t = withBreak();
    SystemContext ctx(List<GameEvent> out) =>
        SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: out.add);
    final s = reborn().copyWith(
      ship: const ShipState(parts: {'cannon': 5, 'hull': 40, 'sail': 0, 'crowsnest': 0, 'cargo': 2}),
    );

    test('목표 레벨로 올리되 내리지 않고, 최대 레벨로 자르고, ShipResupplied(before → after)', () {
      final ev = <GameEvent>[];
      final cannonMax = t.shipParts.byId('cannon').maxLevel;
      final out = resupply(s, {'cannon': 30, 'hull': 10, 'sail': 1 << 30}, ctx(ev));
      expect(out.ship.parts['cannon'], 30);
      expect(out.ship.parts['hull'], 40, reason: '내리지 않음');
      final sailMax = t.shipParts.byId('sail').maxLevel;
      expect(out.ship.parts['sail'], sailMax ?? 1 << 30);
      expect(out.ship.parts['cargo'], 2, reason: '목표 없는 부위 그대로');
      final e = ev.whereType<ShipResupplied>().single;
      expect(e.before['cannon'], 5);
      expect(e.after['cannon'], 30);
      expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson());
      expect(cannonMax == null || cannonMax >= 30, isTrue);
    });

    test('바뀐 게 없으면 이벤트 없음 · 구간 끝(건너뛰기 포함)에서만 보급', () {
      final ev = <GameEvent>[];
      expect(identical(resupply(s, {'cannon': 1}, ctx(ev)), s), isTrue);
      expect(ev, isEmpty);
      final e = CoreEngine(tables: t, clock: ManualClock(start), initial: reborn())
        ..advance(10)
        ..drainEvents()
        ..enqueue(const SkipFastSail())
        ..tick();
      // 표(S2 supplyRatio)·함수가 없으면 보급 없이 끝만 — 부위 그대로
      expect(e.drainEvents().whereType<ShipResupplied>(), isEmpty);
      expect(e.state.ship.parts, reborn().ship.parts);
    });
  });
}

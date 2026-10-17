import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show startBoss;
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 사용자 요청 수용 기준 (피드백 2026-10-17, S1 지시 — 수치를 바꿔도 요청 자체가 깨지지 않게 숫자를 박아 둔다).
/// docs/plans/active/user-feedback-2026-10-17.md #21·#2·#8·#4·#5, 도감 v2 대보스.
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 10, 17);
  final ticksPerSec = Duration.millisecondsPerSecond ~/ t.waves.tickMs;

  /// 새 게임을 [seconds]초 돌린다. 매초: 튜토리얼 확인 단계면 넘기고, 대포 강화를 한 번 시도(살 수 있으면 산다).
  List<GameEvent> play(CoreEngine e, int seconds) {
    final acks = [for (final v in t.meta.raw.obj('tutorial').obj('steps').raw['ack'] as List) (v as num).toInt()];
    final out = <GameEvent>[];
    for (var i = 0; i < seconds * ticksPerSec; i++) {
      if (i % ticksPerSec == 0) {
        final step = e.state.tutorialStep;
        if (step != null && acks.contains(step)) e.enqueue(TutorialAck(step));
        e.enqueue(const UpgradePart('cannon'));
      }
      e.tick();
      out.addAll(e.drainEvents());
    }
    return out;
  }

  CoreEngine fresh(int seed) => CoreEngine(
    tables: t,
    clock: ManualClock(start),
    initial: GameState.newGame(playerId: 'req', seed: seed, now: start, crews: t.meta.startingCrews),
  );

  test('#21 옥토 하나로 시작 → 첫 강화 뒤 1분 안에 연사(직사) 희귀 선원 확정', () {
    expect(t.meta.startingCrews, ['octo']);
    for (final seed in [1, 2, 3]) {
      final e = fresh(seed);
      final got = play(e, 60).whereType<CardGranted>().where((c) => c.source == 'starter').toList();
      expect(got, hasLength(1), reason: 'seed $seed');
      final crew = t.crews.byId(got.single.crewId);
      expect((got.single.rarity, crew.family, got.single.isNew), ('rare', 'direct', true), reason: 'seed $seed');
      expect(e.state.crews.keys, containsAll(['octo', crew.id]));
      expect(activeFleet(e.state, t), contains(crew.id), reason: '받자마자 출전');
    }
  });

  test('첫 무료 10연(폰 피드백 "왜 초반부터 전설이"): 영웅 정확히 1 + 희귀 이하 9, 전설·신화 없음 — 시드 200개', () {
    for (var seed = 1; seed <= 200; seed++) {
      final e =
          CoreEngine(
              tables: t,
              clock: ManualClock(start),
              initial: GameState.newGame(playerId: 'req', seed: seed, now: start, crews: t.meta.startingCrews).copyWith(
                progress: const Progress(stage: 4, bestStage: 4),
              ),
            )
            ..enqueue(const Summon(count: 10))
            ..tick();
      final got = [...e.drainEvents().whereType<CrewSummoned>().single.results.map((r) => r.rarity)]..sort();
      expect(got.where((r) => r == 'hero'), hasLength(1), reason: 'seed $seed');
      expect(got.where((r) => r != 'hero'), everyElement(anyOf('common', 'rare')), reason: 'seed $seed');
      expect(e.state.summonsTotal, 10);
    }
  });

  test('#2 피버 필요 처치: 스테이지 1 = 200, 점점 늘어 스테이지 40부터 1000', () {
    expect(feverKillsAt(t, 1), 200);
    for (var s = 2; s <= 40; s++) {
      expect(feverKillsAt(t, s), greaterThanOrEqualTo(feverKillsAt(t, s - 1)), reason: 'stage $s');
    }
    expect(feverKillsAt(t, 40), 1000);
    expect(feverKillsAt(t, 500), 1000);
  });

  test('#8 첫 배 외형 변화는 1분 안', () {
    for (final seed in [1, 2, 3]) {
      expect(play(fresh(seed), 60).whereType<ShipLookChanged>(), isNotEmpty, reason: 'seed $seed');
    }
  });

  test('#4 초반 핵앤슬래시: 스테이지 1 무리 78마리(60 × 1.3 — 사용자 지시 몬스터 1.3배, 2026-10-17), 덤은 스테이지 20까지 줄어든다', () {
    expect(t.waves.topMobCountAt(1), 78);
    expect(t.waves.topMobCountAt(1), greaterThan(t.waves.topMobCountAt(20)));
  });

  test('#5 bossPreview는 전투가 부르는 보스와 같다(boss_preview_test에 스테이지별로 자세히)', () {
    final s = GameState.newGame(playerId: 'req', seed: 1, now: start).copyWith(
      progress: const Progress(stage: 30, bestStage: 30),
      clearTutorial: true,
    );
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: (_) {});
    final f = Field(stage: 30, shipHpMax: BigNum.one, shipHp: BigNum.one);
    startBoss(f, 30, ctx);
    final boss = f.foes.firstWhere((e) => e.boss);
    final p = bossPreview(s, t);
    expect((p.bossId, p.maxHp.closeTo(boss.maxHp), p.attack.closeTo(boss.attack)), (boss.kind, true, true));
  });

  test('도감 v2: 10단위 벽에는 해역 대보스(25·50 자리는 중간·해역 보스 우선)', () {
    final r = t.regions;
    for (var stage = 10; stage <= 300; stage += 10) {
      final region = r.regionAt(stage);
      final expected = stage % r.stagesPerRegion == 0 ? region.regionBoss : region.wallBoss;
      expect(r.bossAt(stage).id, expected, reason: 'stage $stage');
    }
    expect({for (final g in r.regions) g.wallBoss}, hasLength(r.regions.length), reason: '해역마다 다른 대보스');
  });
}

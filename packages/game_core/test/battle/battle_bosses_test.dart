// 해역 보스 수용 기준 (docs/specs/battle-m3-bosses.md).
import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/bosses.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

void main() {
  final tables = GameTables.load();
  final w = tables.waves;
  final start = DateTime.utc(2026, 11);
  late List<GameEvent> events;
  setUp(() => events = []);

  SystemContext ctx() =>
      SystemContext(tables: tables, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: events.add);
  GameState game(int stage) => GameState.newGame(playerId: 't', seed: 7, now: start).copyWith(
    progress: Progress(stage: stage, bestStage: stage),
  );
  String crewOf(String family) => tables.crews.crews.firstWhere((c) => c.family == family).id;

  /// [stage] 보스 필드 + [family] 선원 한 명.
  (Field, Round, Foe) bossFight(int stage, String family, {bool invincible = false}) {
    final f = Field(stage: stage, shipHpMax: BigNum.from(1e9), shipHp: BigNum.from(1e9));
    final c = ctx();
    startBoss(f, stage, c);
    f.guns = [Gun.of(tables, crewOf(family), power: 1)];
    final boss = f.foes.firstWhere((e) => e.boss)..x = 200;
    return (f, Round(f, c, CombatStats.of(game(stage), tables), rage: 0, invincible: invincible), boss);
  }

  /// 보스 최대 체력의 1%를 [family] 선원으로 때리고, 실제로 들어간 비율(1 = 그대로)을 돌려준다.
  /// (보스 체력이 1e21을 넘으므로 고정값 100으로는 double 정밀도 밖이다.)
  double hit(Round r, Foe boss, String family) {
    final before = boss.hp;
    final dealt = boss.maxHp.times(0.01);
    r.strike((x: boss.x, y: boss.y, hits: [(foe: boss, factor: 1.0)]), dealt, crewId: crewOf(family));
    return ((before - boss.hp) / dealt).toDouble();
  }

  test('1. 25 = 중간 보스, 50 = 해역 보스, 51 = 다음 해역 일반 보스, 체력 배율', () {
    expect(tables.regions.bossAt(25).id, tables.regions.regionAt(25).midBoss);
    expect(tables.regions.bossAt(50).id, 'giant_hermit');
    expect(tables.regions.bossAt(51).id, tables.regions.regionAt(51).boss);
    final (_, _, boss) = bossFight(50, 'direct');
    final normal = stageCurve(w.hpBase, w.hpGrowth, 50).times(w.bossHpMultiplier);
    expect(boss.maxHp.closeTo(normal.times(tables.regions.bosses['giant_hermit']!.hpMultiplier)), isTrue);
  });

  test('2. 대왕 소라게: 직사는 factor배, 투척은 그대로', () {
    final (_, r, boss) = bossFight(50, 'direct');
    expect(hit(r, boss, 'direct'), closeTo(0.5, 1e-6));
    expect(hit(r, boss, 'lob'), closeTo(1, 1e-6));
  });

  test('3. 번개 가오리: 보호막 중 피해 factor배, 관통이 깨고 그대로, 시간이 지나면 다시', () {
    final (f, r, boss) = bossFight(100, 'direct');
    expect(boss.shielded, isTrue);
    expect(f.view(BattleView.empty).enemies.firstWhere((e) => e.boss).shielded, isTrue);
    expect(hit(r, boss, 'direct'), closeTo(tables.regions.bosses['thunder_ray']!.mechanic!.factor, 1e-6));
    expect(hit(r, boss, 'pierce'), closeTo(1, 1e-6));
    expect(boss.shielded, isFalse);
    final ticks = (tables.regions.bosses['thunder_ray']!.mechanic!.intervalSec * 1000 / w.tickMs).ceil();
    for (var i = 0; i < ticks; i++) {
      r.tickBoss();
    }
    expect(boss.shielded, isTrue);
  });

  test('4. 용암 고래: intervalSec마다 배 피해, 무적이면 없음', () {
    final ticks = (tables.regions.bosses['lava_whale']!.mechanic!.intervalSec * 1000 / w.tickMs).ceil();
    final (_, r, _) = bossFight(200, 'direct');
    for (var i = 0; i < ticks; i++) {
      r.tickBoss();
    }
    expect(events.whereType<ShipDamaged>(), hasLength(1));
    events.clear();
    final (_, r2, _) = bossFight(200, 'direct', invincible: true);
    for (var i = 0; i < ticks; i++) {
      r2.tickBoss();
    }
    expect(events.whereType<ShipDamaged>(), isEmpty);
  });

  test('5. 크라켄: 촉수가 살아 있으면 몸통 피해 0, 다 잘리면 들어간다', () {
    final (f, r, boss) = bossFight(250, 'lob');
    final tentacles = f.foes.where((e) => !e.boss).toList();
    expect(tentacles, hasLength(tables.regions.bosses['kraken']!.mechanic!.count));
    expect(hit(r, boss, 'lob'), 0);
    for (final t in tentacles) {
      t.hp = BigNum.zero;
    }
    expect(hit(r, boss, 'lob'), closeTo(1, 1e-6));
  });

  test('6. 유령 함대 제독: intervalSec마다 잡몹 count마리', () {
    final m = tables.regions.bosses['ghost_admiral']!.mechanic!;
    final (f, r, _) = bossFight(300, 'lob');
    for (var i = 0; i < (m.intervalSec * 1000 / w.tickMs).ceil(); i++) {
      r.tickBoss();
    }
    expect(f.living.where((e) => !e.boss), hasLength(m.count));
  });

  test('7. 301은 산호초, 적 tier 1, 체력은 301 곡선', () {
    expect(tables.regions.regionAt(301).id, 'coral');
    final f = Field(stage: 301, shipHpMax: BigNum.one, shipHp: BigNum.one);
    spawnWave(f, 301, ctx(), kind: 'crab');
    expect(f.foes.first.tier, 1);
    expect(f.view(BattleView.empty).enemies.first.tier, 1);
    // 마리당 = 곡선 × waveHpPoolFactor × 몫(mobPoolAt / mobCountAt — 총량 유지, battle_mobs_test)
    final share = w.mobPoolAt(301) / w.mobCountAt(301);
    expect(f.foes.first.maxHp.closeTo(stageCurve(w.hpBase, w.hpGrowth, 301).times(w.waveHpPoolFactor * share)), isTrue);
  });

  test('8. 같은 시드면 해역 보스전 이벤트가 같다', () {
    String run() {
      final e =
          CoreEngine(
              tables: tables,
              clock: ManualClock(start),
              initial: game(250).copyWith(crews: {crewOf('lob'): const CrewState(level: 40)}),
            )
            ..enqueue(const OpSpawnBoss())
            ..advance(400);
      return e.drainEvents().map((x) => x.toJson()).join();
    }

    expect(run(), run());
  });
}

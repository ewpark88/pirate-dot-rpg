import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 몬스터 수 (사용자 지시 2026-10-15): 보이는 마리는 늘리고(초반 10~12, 중반 이후 20~24),
/// 한 파의 HP·공격·골드 총량은 mobCount.pool(예전 마리 수 공식) 기준으로 그대로 둔다.
void main() {
  final t = GameTables.load();
  final w = t.waves;
  final start = DateTime.utc(2026, 11);

  test('옆모습 마리 = 총량 기준 pool (그대로 6 + floor(stage/10), 최대 14) — 몫 1, 옆모습 결과 불변', () {
    for (final st in [1, 37, 80, 500]) {
      expect(w.mobCountAt(st), w.mobPoolAt(st));
    }
    expect(
      [
        for (final st in [1, 37, 80, 500]) w.mobPoolAt(st),
      ],
      [6, 9, 14, 14],
    );
  });

  test('탑다운 마리 = 무리 습격: 초반 30~40, 중반 50~100, 상한 150', () {
    expect(w.topMobCountAt(1), inInclusiveRange(30, 40));
    expect(w.topMobCountAt(10), inInclusiveRange(30, 40));
    expect(w.topMobCountAt(60), inInclusiveRange(50, 100));
    expect(w.topMobCountAt(100), inInclusiveRange(60, 100));
    expect(w.topMobCountAt(9999), 150);
  });

  for (final stage in [1, 10, 37, 120]) {
    test('스테이지 $stage 탑다운: 한 파 HP·공격·골드 합 = 단일 곡선 × pool (마리 수와 무관)', () {
      final f = Field(stage: stage, shipHpMax: BigNum.one, shipHp: BigNum.one)..geometry = geometryFor(t, stage);
      final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: (_) {});
      spawnWave(f, stage, ctx, kind: 'crab'); // crab hpScale 1
      final wave = f.foes.where((x) => !x.vanguard).toList(); // 돌격대(waves.top.vanguard)는 파 총량 밖의 덤
      expect(wave, hasLength(w.topMobCountAt(stage)));
      final pool = w.mobPoolAt(stage);
      BigNum sum(BigNum Function(Foe) of) => wave.fold(BigNum.zero, (a, x) => a + of(x));
      expect(
        sum((x) => x.maxHp).closeTo(stageCurve(w.hpBase, w.hpGrowth, stage).times(w.waveHpPoolFactor * pool)),
        isTrue,
      );
      expect(sum((x) => x.attack).closeTo(stageCurve(w.attackBase, w.attackGrowth, stage).times(pool)), isTrue);
      expect(sum((x) => x.gold).closeTo(stageCurve(w.goldBase, w.goldGrowth, stage).times(pool)), isTrue);
    });
  }

  test('운영자 OpSetWave(count)는 마리 수를 정하고 마리당 값은 원래(pool 나눔 없음) — 측정 장면 호환', () {
    final f = Field(stage: 5, shipHpMax: BigNum.one, shipHp: BigNum.one);
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: (_) {});
    spawnWave(f, 5, ctx, count: 3, kind: 'crab');
    expect(f.foes, hasLength(3));
    expect(f.foes.first.maxHp.closeTo(stageCurve(w.hpBase, w.hpGrowth, 5).times(w.waveHpPoolFactor)), isTrue);
  });
}

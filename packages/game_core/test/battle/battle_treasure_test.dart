import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 보물 바다(환생 v2): Field.enemyHpScale이 무리·보스 체력에 곱해진다.
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11);
  SystemContext ctx() => SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(1), onEvent: (_) {});

  test('무리·보스 체력 × enemyHpScale', () {
    BigNum waveHp(double scale) {
      final f = Field(stage: 30, shipHpMax: BigNum.one, shipHp: BigNum.one)..enemyHpScale = scale;
      spawnWave(f, 30, ctx(), kind: 'crab');
      return f.foes.fold(BigNum.zero, (a, e) => a + e.maxHp);
    }

    BigNum bossHp(double scale) {
      final f = Field(stage: 30, shipHpMax: BigNum.one, shipHp: BigNum.one)..enemyHpScale = scale;
      startBoss(f, 30, ctx(), emit: false);
      return f.foes.firstWhere((e) => e.boss).maxHp;
    }

    expect((waveHp(2) / waveHp(1)).toDouble(), closeTo(2, 1e-9));
    expect((bossHp(3.5) / bossHp(1)).toDouble(), closeTo(3.5, 1e-9));
  });
}

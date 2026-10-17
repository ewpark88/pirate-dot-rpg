import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/testing.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 피버 타임 (platform-fun-fever A, 수용 기준 1~3): 처치로 게이지가 차면 자동 10초, 피해·골드 배수.
void main() {
  final t = EconomyHarness.tables;
  final f = t.meta.raw.obj('fever');
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  GameState withFever(double gauge, {int ticksLeft = 0}) => h.newGame().copyWith(
    progress: Progress(fever: gauge),
    battle: BattleView(shipHp: BigNum.one, shipHpMax: BigNum.one, fever: gauge, feverTicksLeft: ticksLeft),
  );

  test('게이지 = 처치 수(시간 충전 없음): 1마리 = 1 ÷ feverKillsAt, 동시 처치 배수 없음, 보스 + bossKill', () {
    final need = feverKillsAt(t, 1);
    expect(need, f.integer('killsStart'));
    expect(feverStep(withFever(0), h.ctx, kills: 4, bossKilled: false).progress.fever, closeTo(4 / need, 1e-12));
    expect(feverStep(withFever(0), h.ctx, kills: 0, bossKilled: false).progress.fever, 0);
    expect(
      feverStep(withFever(0), h.ctx, kills: 0, bossKilled: true).progress.fever,
      closeTo(f.number('bossKill'), 1e-12),
    );
  });

  test('필요 처치 수(피드백 #2): 스테이지 1 killsStart → killsRampStage까지 늘어 killsMax에서 멈춘다', () {
    final ramp = f.integer('killsRampStage');
    expect(feverKillsAt(t, 1), f.integer('killsStart'));
    expect(feverKillsAt(t, ramp ~/ 2), inExclusiveRange(f.integer('killsStart'), f.integer('killsMax')));
    expect(feverKillsAt(t, ramp), f.integer('killsMax'));
    expect(feverKillsAt(t, 100000), f.integer('killsMax'));
  });

  test('특정 조건: addFever는 게이지에 더하고, 피버 중엔 무시', () {
    expect(
      addFever(withFever(0.2), f.number('challengeWin')).progress.fever,
      closeTo(0.2 + f.number('challengeWin'), 1e-12),
    );
    expect(addFever(withFever(0, ticksLeft: 5), 0.5).progress.fever, 0);
  });

  test('기준 1: 게이지가 차면 FeverStarted, durationSec 동안 피버, 끝나면 FeverEnded·게이지 0', () {
    var s = feverStep(withFever(0.999), h.ctx, kills: 1, bossKilled: false);
    final started = h.of<FeverStarted>().single;
    final ticks = (f.number('durationSec') * 1000 / t.waves.tickMs).round();
    expect(started.untilTick - started.tick, ticks);
    expect(s.battle!.feverTicksLeft, ticks);
    expect(s.progress.fever, 0);
    for (var i = 0; i < ticks; i++) {
      s = feverStep(s, h.ctx, kills: 3, bossKilled: false);
    }
    expect(h.of<FeverEnded>(), hasLength(1));
    expect(s.battle!.feverTicksLeft, 0);
  });

  test('기준 3: 피버 중 처치해도 게이지 그대로 0', () {
    final s = feverStep(withFever(0, ticksLeft: 50), h.ctx, kills: 10, bossKilled: true);
    expect(s.progress.fever, 0);
    expect(s.battle!.feverTicksLeft, 49);
  });

  test('피버 중 피해 % 합 + (damageMultiplier − 1), 골드 × goldMultiplier', () {
    final off = CombatStats.of(withFever(0), t);
    final on = CombatStats.of(withFever(0, ticksLeft: 5), t);
    expect(on.bonus - off.bonus, closeTo(f.number('damageMultiplier') - 1, 1e-12));
    expect(on.goldMultiplier / off.goldMultiplier, closeTo(f.number('goldMultiplier'), 1e-12));
  });

  test('엔진: 게이지가 거의 찬 상태에서 처치가 나면 피버가 켜지고 BattleView에 남는다', () {
    final s0 = h.newGame().copyWith(
      crews: const {'octo': CrewState(level: 30), 'turtle': CrewState(level: 30)},
      progress: const Progress(fever: 0.999),
      ship: const ShipState(parts: {'cannon': 40, 'hull': 40, 'sail': 10, 'crowsnest': 5, 'cargo': 0}),
    );
    final e = CoreEngine(tables: t, clock: ManualClock(EconomyHarness.start), initial: s0);
    var started = false;
    for (var i = 0; i < 2000 && !started; i++) {
      e.tick();
      started = e.drainEvents().whereType<FeverStarted>().isNotEmpty;
    }
    expect(started, isTrue);
    e.tick();
    expect(e.state.battle!.feverTicksLeft, greaterThan(0));
  });
}

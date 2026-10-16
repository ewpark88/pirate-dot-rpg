import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 빠른 항해 보급 (사용자 긴급 2026-10-16: 환생 → 빠른 항해 스테이지 83 → 골드가 화물칸에 막혀 배를 못 올리고 침몰).
void main() {
  final t = EconomyHarness.tables;
  const arrive = 83;

  GameState reborn({Map<String, int>? parts}) =>
      GameState.newGame(
        playerId: 'fs',
        seed: 7,
        now: EconomyHarness.start,
        crews: const ['octo', 'turtle', 'shark', 'pang'],
      ).copyWith(
        crews: const {
          'octo': CrewState(level: 45),
          'turtle': CrewState(level: 45),
          'shark': CrewState(level: 45),
          'pang': CrewState(level: 45),
        },
        progress: const Progress(stage: arrive, bestStage: 160, rebirths: 1),
        ship: ShipState(parts: parts ?? const {'cannon': 0, 'hull': 0, 'sail': 0, 'crowsnest': 0, 'cargo': 0}),
        clearTutorial: true,
      );

  test('보급 레벨: 스테이지가 높을수록 높고, 지금보다 낮추지 않으며, 최대 레벨을 넘지 않는다', () {
    final s = reborn();
    final at40 = fastSailSupplyLevels(s, t, 40);
    final at83 = fastSailSupplyLevels(s, t, arrive);
    for (final p in t.shipParts.parts) {
      expect(at83[p.id], greaterThanOrEqualTo(at40[p.id] ?? 0), reason: p.id);
      final max = p.maxLevel;
      if (max != null) {
        expect(at83[p.id], lessThanOrEqualTo(max));
      }
    }
    expect(at83['hull'], greaterThan(0));
    expect(at83['cannon'], greaterThan(0));
    final high = reborn(parts: const {'cannon': 99, 'hull': 99, 'sail': 30, 'crowsnest': 45, 'cargo': 99});
    expect(fastSailSupplyLevels(high, t, arrive)['cannon'], 99);
  });

  test('회귀: 보급받은 배는 도착 스테이지 무리에서 60초 동안 가라앉지 않는다(보급 없으면 가라앉는다)', () {
    int sinks(GameState s) {
      // 첫 틱은 전장을 만든다(배 체력 자리값)
      final e = CoreEngine(tables: t, clock: ManualClock(EconomyHarness.start), initial: s)
        ..tick()
        ..drainEvents();
      var n = 0;
      for (var i = 0; i < 60 * 1000 ~/ t.waves.tickMs; i++) {
        final before = e.state.battle!.shipHp;
        final stage = e.state.progress.stage;
        e
          ..tick()
          ..drainEvents();
        final b = e.state.battle!;
        // 침몰 = 같은 스테이지에서 체력이 반 아래였다가 가득으로 돌아옴(재시작). 스테이지가 바뀌어 차는 건 빼고.
        if (e.state.progress.stage == stage && b.shipHp == b.shipHpMax && before < b.shipHpMax.times(0.5)) {
          n++;
        }
      }
      return n;
    }

    final bare = reborn();
    final supplied = reborn(parts: fastSailSupplyLevels(bare, t, arrive));
    expect(sinks(supplied), 0, reason: '보급 레벨 ${supplied.ship.parts}');
    expect(supplied.progress.stage, arrive);
    expect(sinks(bare), greaterThan(0), reason: '보급 없이는 침몰(사용자 신고 재현)');
  });
}

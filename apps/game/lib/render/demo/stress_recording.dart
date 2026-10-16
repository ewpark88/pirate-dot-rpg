import 'dart:math' as math;

import 'package:game_core/game_core.dart';

/// 실기기 성능 측정용 탑다운 부하 장면 (docs/specs/render-perf.md 규칙 2, T4-3 — 옆모습 부하 장면을 대신).
/// 무작위 시드 고정이라 기기마다 같다: 적 count마리가 배(135, 240) 둘레 반지름 120~(120+spread)에서 다가오고,
/// 선원 6명이 매 틱 쏘며(투척·직사·관통·전기·물속·공중), 3틱마다 처치. 200틱(10초) 뒤 반복.
const _kinds = ['crab', 'piranha', 'jelly', 'gull', 'urchin', 'puffer'];

List<RecordedTick> stressRecording({int count = 150, int ticks = 200, double spread = 120}) {
  final rng = math.Random(7);
  final start = [for (var i = 0; i < count; i++) (rng.nextDouble() * 2 * math.pi, 120 + rng.nextDouble() * spread)];
  final crews = ['octo', 'pang', 'sword', 'turtle', 'puffer', 'gull'];
  return [
    for (var t = 0; t < ticks; t++)
      RecordedTick(
        BattleView(
          tick: t,
          shipHp: BigNum.from(100),
          shipHpMax: BigNum.from(100),
          mode: 'top',
          stage: 31,
          fleet: [for (final c in crews) FleetSlot(crewId: c)],
          enemies: [
            for (var i = 0; i < count; i++)
              () {
                final (a, r0) = start[i];
                final r = math.max<double>(40, r0 - t * 0.6);
                return EnemyView(
                  id: i + 1,
                  kind: _kinds[i % _kinds.length],
                  x: 135 + math.cos(a) * r,
                  y: 240 + math.sin(a) * r,
                  hpRatio: 1,
                  heading: a + math.pi,
                  layer: i % 3 == 1 ? 'underwater' : (i % 6 == 3 ? 'air' : 'surface'),
                );
              }(),
          ],
        ),
        [
          for (var k = 0; k < 6; k++) ...[
            AttackFired(
              t,
              crewId: crews[k],
              family: ['lob', 'direct', 'pierce', 'shock', 'underwater', 'air'][k],
              targetIds: [(t * 7 + k * 13) % count + 1],
              x: 135,
              y: 120,
            ),
            Damage(t, targetId: (t * 7 + k * 13) % count + 1, amount: BigNum.from(123 + t), crewId: crews[k]),
          ],
          if (t % 3 == 0) Kill(t, targetId: (t * 11) % count + 1, gold: BigNum.from(9), x: 160, y: 180),
        ],
      ),
  ];
}

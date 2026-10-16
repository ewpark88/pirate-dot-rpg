import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';

/// 탑다운(T1 엔진, Settings.battleView 'top') 실제 전투 기록 — 렌더 T2 테스트·시안용. 같은 시드면 같은 기록.
List<RecordedTick> topRecording(
  GameTables t, {
  int ticks = 240,
  int stage = 31,
  int bossAt = -1,
  double fever = 0,
  Map<String, int> levels = const {'octo': 30, 'pang': 28, 'sword': 26, 'turtle': 24},
}) {
  final start = DateTime.utc(2026, 11);
  final state = GameState.newGame(playerId: 'top', seed: 2026, now: start).copyWith(
    progress: Progress(stage: stage, bestStage: stage, rage: 0.6, fever: fever),
    ship: const ShipState(parts: {'cannon': 24, 'hull': 40, 'sail': 10, 'crowsnest': 15, 'cargo': 10}),
    crews: {for (final MapEntry(:key, :value) in levels.entries) key: CrewState(level: value)},
    collection: levels.keys.toSet(),
  );
  final engine = CoreEngine(tables: t, clock: ManualClock(start), initial: state);
  final out = <RecordedTick>[];
  for (var i = 0; i < ticks; i++) {
    if (i == bossAt) engine.enqueue(const OpSpawnBoss());
    engine.tick();
    out.add(RecordedTick(engine.state.battle!, engine.drainEvents()));
  }
  return out;
}

/// 피버를 [at] 틱부터 [ticks] 틱 동안 강제로 켠 기록 (엔진의 피버 게이지·처치 수가 바뀌어도 장면이 안 흔들리게, S1).
/// [at] 틱에 FeverStarted를 넣고, 그 뒤 프레임의 feverTicksLeft를 줄여 간다.
List<RecordedTick> withFever(List<RecordedTick> rec, {int at = 60, int ticks = 200}) => [
  for (var i = 0; i < rec.length; i++)
    if (i < at || i >= at + ticks)
      rec[i]
    else
      RecordedTick(rec[i].frame.copyWith(feverTicksLeft: at + ticks - i), [
        ...rec[i].events,
        if (i == at) FeverStarted(rec[i].frame.tick, untilTick: rec[i].frame.tick + ticks),
      ]),
];

/// 배 피격을 [at] 틱에 강제로 넣는다 (엔진 균형이 바뀌어 적이 배에 못 닿아도 장면이 안 흔들리게, S1):
/// 그 틱 배에 가장 가까운 적이 때린 것으로 — ShipDamaged fromX·fromY = 그 적 자리.
List<RecordedTick> withShipHit(List<RecordedTick> rec, {int at = 120}) {
  final f = rec[at].frame;
  final sx = f.shipX ?? 135;
  final sy = f.shipY ?? 240;
  EnemyView? near;
  var best = double.infinity;
  for (final e in f.enemies) {
    final d = (e.x - sx) * (e.x - sx) + (e.y - sy) * (e.y - sy);
    if (d < best) (near, best) = (e, d);
  }
  if (near == null) throw StateError('틱 $at에 적이 없다');
  return [
    for (var i = 0; i < rec.length; i++)
      i == at
          ? RecordedTick(f, [
              ...rec[i].events,
              ShipDamaged(f.tick, amount: BigNum.from(120), hpRatio: 0.9, fromX: near.x, fromY: near.y),
            ])
          : rec[i],
  ];
}

/// 보스 포탄을 [at] 틱에 강제로 넣는다: 배 앞 80단위에서 BossFired + 같은 틱 ShipDamaged(엔진과 같은 짝).
List<RecordedTick> withBossFire(List<RecordedTick> rec, {int at = 120}) {
  final f = rec[at].frame;
  final x = f.shipX ?? 135;
  final y = (f.shipY ?? 240) - 80;
  return [
    for (var i = 0; i < rec.length; i++)
      i == at
          ? RecordedTick(f, [
              ...rec[i].events,
              BossFired(f.tick, x: x, y: y),
              ShipDamaged(f.tick, amount: BigNum.from(900), hpRatio: 0.8, fromX: x, fromY: y),
            ])
          : rec[i],
  ];
}

/// 위협 연출 주입 (S5 EnemyFired·EnemyEmerging): [at] 틱에 배에서 먼 적 둘이 불씨·물 탄을 쏘고(1초 비행),
/// 배 오른쪽 앞에서 한 마리가 솟아오르기 예고(0.6초).
List<RecordedTick> withThreat(List<RecordedTick> rec, {int at = 120}) {
  final f = rec[at].frame;
  final sx = f.shipX ?? 135;
  final sy = f.shipY ?? 240;
  final far = [...f.enemies]
    ..sort((a, b) => ((b.x - sx).abs() + (b.y - sy).abs()).compareTo((a.x - sx).abs() + (a.y - sy).abs()));
  if (far.length < 2) throw StateError('틱 $at에 적이 둘 이상 있어야 한다');
  return [
    for (var i = 0; i < rec.length; i++)
      i == at
          ? RecordedTick(f, [
              ...rec[i].events,
              EnemyFired(f.tick, enemyId: far[0].id, fromX: far[0].x, fromY: far[0].y, flightTicks: 20, kind: 'ember'),
              EnemyFired(f.tick, enemyId: far[1].id, fromX: far[1].x, fromY: far[1].y, flightTicks: 20, kind: 'water'),
              EnemyEmerging(f.tick, enemyId: -1, x: sx + 34, y: sy - 26, warnTicks: 12),
            ])
          : rec[i],
  ];
}

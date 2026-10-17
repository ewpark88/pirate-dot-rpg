import 'dart:math' as math;

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
    progress: Progress(stage: stage, bestStage: stage, fever: fever),
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

/// 보스 행동 v2 예고·동작 주입 (S5 BossPatternShown): [at] 틱에 배에서 먼 적 하나를 보스 자리로 [kind] 예고(12틱), [at]+12에 동작.
List<RecordedTick> withBossPattern(List<RecordedTick> rec, String kind, {int at = 120}) {
  final f = rec[at].frame;
  final sx = f.shipX ?? 135;
  final sy = f.shipY ?? 240;
  final far = [...f.enemies]
    ..sort((a, b) => ((b.x - sx).abs() + (b.y - sy).abs()).compareTo((a.x - sx).abs() + (a.y - sy).abs()));
  final e = far.first;
  // 화면 안에 보이게 배 앞 90단위 쪽으로 당긴 자리.
  final bx = sx + (e.x - sx).clamp(-80.0, 80.0);
  final by = sy - 90.0;
  final angle = math.atan2(sy - by, sx - bx);
  BossPatternShown ev(int tick, String phase) => BossPatternShown(
    tick,
    enemyId: e.id,
    kind: kind,
    phase: phase,
    warnTicks: 12,
    x: bx,
    y: by,
    angle: angle,
    count: kind == 'summon' ? 4 : 5,
    radius: 56,
  );
  return [
    for (var i = 0; i < rec.length; i++)
      i == at || i == at + 12
          ? RecordedTick(rec[i].frame, [...rec[i].events, ev(rec[i].frame.tick, i == at ? 'warn' : 'act')])
          : rec[i],
  ];
}

/// 화물칸 가득 주입 (S2 GoldOverflow — 0.5초마다): [at]·[at]+10 틱.
List<RecordedTick> withGoldOverflow(List<RecordedTick> rec, {int at = 120}) => [
  for (var i = 0; i < rec.length; i++)
    i == at || i == at + 10
        ? RecordedTick(rec[i].frame, [...rec[i].events, GoldOverflow(rec[i].frame.tick, lost: BigNum.from(1000))])
        : rec[i],
];

/// 빠른 항해 돌파 주입 (S5 fast-sail): [at] 틱에 시작(31 → 43), build 5번(간격 40·30·22·17·13틱) → rush 6번(5틱) → finale(12틱 뒤) → 끝.
/// 그 사이 프레임에 BattleView.fastSail을 넣는다. 보스 자리 = 배 앞 90.
List<RecordedTick> withFastSail(List<RecordedTick> rec, {int at = 60}) {
  final strikes = <int, (String, double)>{};
  var t = at + 20;
  for (final gap in const [40, 30, 22, 17, 13]) {
    t += gap;
    strikes[t] = ('build', 40 / gap);
  }
  for (var k = 0; k < 6; k++) {
    t += 5;
    strikes[t] = ('rush', 8);
  }
  t += 12;
  strikes[t] = ('finale', 8);
  final end = t + 10;
  var combo = 0;
  return [
    for (var i = 0; i < rec.length; i++)
      () {
        final f = rec[i].frame;
        final sx = f.shipX ?? 135;
        final sy = f.shipY ?? 240;
        final s = strikes[i];
        if (s != null) combo++;
        final events = [
          ...rec[i].events,
          if (i == at) FastSailStarted(f.tick, from: 31, to: 43),
          if (s != null)
            BreakthroughStrike(
              f.tick,
              stage: 31 + combo,
              bossId: 'enemy_ship',
              x: sx,
              y: sy - 90,
              combo: combo,
              phase: s.$1,
              speed: s.$2,
            ),
          if (i == end)
            FastSailEnded(
              f.tick,
              from: 31,
              to: 43,
              stages: 12,
              gold: BigNum.from(1000),
              lost: BigNum.zero,
              gems: 5,
              skipped: false,
            ),
        ];
        final inSail = i >= at && i < end;
        final frame = inSail
            ? BattleView.fromJson({
                ...f.toJson(),
                'fastSail': {'from': 31, 'to': 43, 'combo': combo, 'phase': s?.$1 ?? 'build', 'speed': s?.$2 ?? 1},
              })
            : f;
        return RecordedTick(frame, events);
      }(),
  ];
}

/// 현상금 주입 (S2·S5 bounty): [at]에 BountyStarted, 그 뒤 프레임에 BattleView.bounty, [clearAt]에 BountyCleared(젬 30).
List<RecordedTick> withBounty(List<RecordedTick> rec, {int at = 60, int clearAt = 240}) => [
  for (var i = 0; i < rec.length; i++)
    RecordedTick(
      i >= at && i < clearAt
          ? BattleView.fromJson({
              ...rec[i].frame.toJson(),
              'bounty': {'bossId': 'enemy_ship', 'tier': 3, 'ticksLeft': clearAt - i},
            })
          : rec[i].frame,
      [
        ...rec[i].events,
        if (i == at) BountyStarted(rec[i].frame.tick, bossId: 'enemy_ship', tier: 3, timeLimitTicks: clearAt - at),
        if (i == clearAt)
          BountyCleared(
            rec[i].frame.tick,
            bossId: 'enemy_ship',
            tier: 3,
            reward: const BountyReward(type: 'gems', amount: 30),
          ),
      ],
    ),
];

/// 돌격대·상위 착탄 폭발 주입 (S5 chargers): 모든 프레임에서 앞 8마리를 vanguard로, [at] 틱에 pang(신화면 무지개)의 splashRadius 30 한 발.
List<RecordedTick> withVanguardSplash(List<RecordedTick> rec, {int at = 120}) => [
  for (var i = 0; i < rec.length; i++)
    () {
      final j = rec[i].frame.toJson();
      final enemies = [for (final e in j['enemies'] as List) Map<String, dynamic>.from(e as Map)];
      for (var k = 0; k < enemies.length && k < 8; k++) {
        enemies[k]['vanguard'] = true;
      }
      final frame = BattleView.fromJson({...j, 'enemies': enemies});
      final t = frame.enemies.isEmpty ? null : frame.enemies[frame.enemies.length ~/ 2];
      return RecordedTick(frame, [
        ...rec[i].events,
        if (i == at && t != null)
          AttackFired(
            frame.tick,
            crewId: 'pang',
            family: 'direct',
            targetIds: [t.id],
            x: t.x,
            y: t.y,
            splashRadius: 30,
          ),
      ]);
    }(),
];

/// 보스 처치를 [at] 틱에 강제로 넣는다(피드백 #18 보상 터짐): 그 틱 보스에게 Kill(금 [gold]) + BossCleared(젬 [gems]),
/// 다음 틱부터 그 보스를 프레임에서 뺀다. 보스는 [topRecording]의 bossAt으로 먼저 불러 둔다.
List<RecordedTick> withBossKill(List<RecordedTick> rec, {required int at, int gems = 10, int gold = 52000}) {
  final f = rec[at].frame;
  final boss = f.enemies.firstWhere((e) => e.boss, orElse: () => throw StateError('틱 $at에 보스가 없다'));
  return [
    for (var i = 0; i < rec.length; i++)
      if (i < at)
        rec[i]
      else if (i == at)
        RecordedTick(f, [
          ...rec[i].events,
          Kill(f.tick, targetId: boss.id, gold: BigNum.from(gold), x: boss.x, y: boss.y),
          BossCleared(f.tick, stage: f.stage, gems: gems),
        ])
      else
        RecordedTick(
          rec[i].frame.copyWith(
            enemies: [
              for (final e in rec[i].frame.enemies)
                if (e.id != boss.id) e,
            ],
          ),
          [
            for (final e in rec[i].events)
              if (e is! Kill || e.targetId != boss.id) e,
          ],
        ),
  ];
}

/// 보물상자를 [at] 틱 전 40틱 동안 배 오른쪽 앞에 띄우고 [at] 틱에 연다(피드백 #15 — ChestOpened, 탭·광고 같음).
/// [adAt]이 있으면 그 틱에 광고 보상(SaveRequested adReward — 순풍 등 배 버프).
List<RecordedTick> withChestOpen(List<RecordedTick> rec, {required int at, int? adAt, int gold = 8000}) {
  final f = rec[at].frame;
  final x = (f.shipX ?? 135) + 40;
  final y = (f.shipY ?? 240) - 70;
  return [
    for (var i = 0; i < rec.length; i++)
      if (i >= at - 40 && i < at)
        RecordedTick(
          rec[i].frame.copyWith(
            chest: ChestView(x: x, y: y, ticksLeft: 200),
          ),
          rec[i].events,
        )
      else if (i == at || i == adAt)
        RecordedTick(rec[i].frame, [
          ...rec[i].events,
          if (i == at) ChestOpened(rec[i].frame.tick, gold: BigNum.from(gold)),
          if (i == adAt) SaveRequested(rec[i].frame.tick, reason: 'adReward'),
        ])
      else
        rec[i],
  ];
}

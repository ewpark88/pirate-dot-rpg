import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_field.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_core/src/ports/ports.dart';

/// 한 바퀴(라디안).
const double turn = math.pi / half;

/// 탑다운 스폰 자리: 화면 밖 어디서, 어떤 대열로 나오는가 (스폰 패턴 — 사용자 지시 '스폰 패턴 섞기', S2 표).
/// 수치(마리 수·HP·골드)는 spawnWaveFoes가 정하고, 여기서는 자리와 등장 시각만 정한다.
class TopSpawn {
  TopSpawn(this.top, this.spawnSpacing);

  TopField top; // 지금 배 자리(TopGeometry.weave)

  /// 옆모습 무리 간격(waves.field.spawnSpacing) — swarmSpacing이 없을 때.
  final double spawnSpacing;

  /// 배 중심에서 [angle] 방향으로 보이는 테두리까지의 거리.
  double toBorder(double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    final tx = c > 0 ? (top.width - top.shipX) / c : (c < 0 ? -top.shipX / c : double.infinity);
    final ty = s > 0 ? (top.height - top.shipY) / s : (s < 0 ? -top.shipY / s : double.infinity);
    return math.min(tx, ty);
  }

  void place(Foe e, double angle, double distance) {
    e
      ..x = top.shipX + math.cos(angle) * distance
      ..y = top.shipY + math.sin(angle) * distance;
  }

  /// 화면 밖 출발 거리: 테두리 바깥과 접근 원 중 먼 곳(어느 방향이든 원 안에서 걷는 거리가 같게).
  double startDistance(Foe e, double angle) =>
      math.max(toBorder(angle) + top.spawnMargin + top.radiusOf(e), top.approachRadius);

  /// 방향 하나: 가중(spawnWeights)이 있으면 위·오른쪽·아래·왼쪽 사분면을 가중대로 고른 뒤 그 안에서 고르게.
  double heading(Rng rng) {
    final wt = top.spawnWeights;
    if (wt == null) return rng.nextDouble() * turn;
    const quarter = turn * half * half;
    final r = rng.nextDouble() * (wt.up + wt.side + wt.down + wt.side);
    // 사분면 중심: 위 −90°, 오른쪽 0°, 아래 90°, 왼쪽 180°.
    final center = r < wt.up
        ? -quarter
        : r < wt.up + wt.side
        ? 0.0
        : r < wt.up + wt.side + wt.down
        ? quarter
        : quarter / half;
    return center + (rng.nextDouble() - half) * quarter;
  }

  /// 이번 파의 패턴: spawnPatterns 가중 추첨. 표에 없으면 늘 swarm(난수를 쓰지 않는다 — 옛 순서 유지).
  String pick(Rng rng) {
    final p = top.spawnPatterns;
    if (p == null || p.isEmpty) return 'swarm';
    var r = rng.nextDouble() * p.values.fold(0.0, (a, b) => a + b);
    for (final e in p.entries) {
      r -= e.value;
      if (r < 0) return e.key;
    }
    return p.keys.last;
  }

  /// [added] 적들의 자리(와 scatter면 등장 대기 시간)를 패턴대로 정한다.
  void arrange(List<Foe> added, Rng rng) {
    if (added.isEmpty) return;
    switch (pick(rng)) {
      case 'scatter':
        _scatter(added, rng);
      case 'arc':
        _arc(added, rng);
      default:
        _swarm(added, rng);
    }
  }

  /// 무리: 방향 묶음(swarmGroups)마다 퍼져서, 묶음 안 k번째는 k × 줄 간격만큼 더 바깥.
  void _swarm(List<Foe> added, Rng rng) {
    final groups = top.swarmGroupsMin + rng.nextInt(top.swarmGroupsMax - top.swarmGroupsMin + 1);
    final heads = [for (var g = 0; g < groups; g++) heading(rng)];
    final spread = top.swarmSpreadDeg * radiansPerDegree;
    final gap = top.swarmSpacing > 0 ? top.swarmSpacing : spawnSpacing;
    for (var i = 0; i < added.length; i++) {
      final angle = heads[i % groups] + (rng.nextDouble() - half) * spread;
      place(added[i], angle, startDistance(added[i], angle) + (i ~/ groups) * gap);
    }
  }

  /// 흩뿌림: 사방에서 1~2마리씩, 간격 scatterGapSec 안에서 무작위로 파 동안 흘러 들어온다.
  /// 아직 안 나온 적은 화면 밖에서 기다린다(holdSec) — 살아 있는 적으로 쳐서 파가 일찍 끝나지 않고, 화면 밖이라 조준되지 않는다.
  void _scatter(List<Foe> added, Rng rng) {
    var wait = 0.0;
    var i = 0;
    while (i < added.length) {
      final batch = 1 + rng.nextInt(1 + 1); // 1~2마리
      for (var k = 0; k < batch && i < added.length; k++, i++) {
        final angle = heading(rng);
        place(added[i], angle, startDistance(added[i], angle));
        added[i].holdSec = wait;
      }
      wait += top.scatterGapMin + rng.nextDouble() * (top.scatterGapMax - top.scatterGapMin);
    }
  }

  /// 반원 대열: 한 방향에서 넓게(arcSpreadDeg) 줄지어, 칸이 모자라면 한 줄 더 바깥에.
  void _arc(List<Foe> added, Rng rng) {
    final head = heading(rng);
    final spread = top.arcSpreadDeg * radiansPerDegree;
    final out = startDistance(added.first, head);
    final perRow = math.max(1, (spread * out / (top.mobRadius / half)).floor());
    for (var i = 0; i < added.length; i++) {
      final row = i ~/ perRow;
      final inRow = math.min(perRow, added.length - row * perRow);
      final u = inRow == 1 ? half : (i % perRow) / (inRow - 1);
      final angle = head + (u - half) * spread;
      place(added[i], angle, startDistance(added[i], angle) + row * (top.mobRadius / half));
    }
  }
}

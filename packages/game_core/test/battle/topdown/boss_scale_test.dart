import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 보스 크기(S1 2026-10-18 핵앤슬래시 존재감 — S3가 그림을 대보스 1.8·해역 1.4·그 밖 1.2배로 키움): waves.top.bossScale.
/// 엔진은 충돌 반경을 배율대로, standoff를 늘어난 반경 × standoffGrow만큼 늘려 그림이 배와 겹치지 않게 하고,
/// 늘어난 가장자리 거리만큼 사거리에 더해 닿는 거리(= 보스전 시간)는 그대로 둔다. 큰 보스(orbitMax 넘음)는 돌지 않는다.
void main() {
  final t = GameTables.load();
  final top = t.waves.raw.obj('top');
  final start = DateTime.utc(2026, 11);

  test('분류별 배율·standoff — 대보스가 가장 멀리, 보통 보스는 조금', () {
    final wall = t.regions.regions.first.wallBoss!;
    final region = t.regions.regions.first.regionBoss;
    final other = t.regions.regions.first.boss;
    expect(bossScaleOf(t, wall), top.obj('bossScale').number('wall'));
    expect(bossScaleOf(t, region), top.obj('bossScale').number('region'));
    expect(bossScaleOf(t, other), top.obj('bossScale').number('other'));
    final base = top.number('bossStandoff');
    expect(bossStandoffFor(t, wall), greaterThan(bossStandoffFor(t, region)));
    expect(bossStandoffFor(t, region), greaterThan(bossStandoffFor(t, other)));
    expect(bossStandoffFor(t, other), greaterThan(base));
  });

  /// [stage] 보스를 불러 [sec]초 — 보스 자리(배 기준) 기록.
  List<({double dx, double dy})> fight(int stage, double sec) {
    var s = GameState.newGame(playerId: 'b', seed: 5, now: start);
    s = s.copyWith(
      progress: s.progress.copyWith(stage: stage, bestStage: stage),
    );
    final e = CoreEngine(tables: t, clock: ManualClock(start), initial: s)
      ..enqueue(const OpSetInvincible(on: true))
      ..enqueue(const OpSpawnBoss());
    final out = <({double dx, double dy})>[];
    for (var i = 0; i < (sec * 1000 / t.waves.tickMs).round(); i++) {
      e
        ..tick()
        ..drainEvents();
      final v = e.state.battle!;
      final b = v.enemies.where((x) => x.boss).firstOrNull;
      if (b == null) continue;
      out.add((dx: b.x - (v.shipX ?? top.number('shipX')), dy: b.y - (v.shipY ?? top.number('shipY'))));
    }
    return out;
  }

  test('대보스: 더 먼 standoff에 서고 원을 돌지 않는다 — 결투 중에도 배 위쪽(화면 안)', () {
    final stage = t.regions.wallEvery; // 10 = 해역 대보스
    final wall = t.regions.bossAt(stage).id;
    expect(t.regions.bossClassOf(wall), 'wall');
    final r = bossStandoffFor(t, wall);
    final path = fight(stage, 20);
    final settled = path.where((p) => (math.sqrt(p.dx * p.dx + p.dy * p.dy) - r).abs() < 1).toList();
    expect(settled, isNotEmpty, reason: '대보스가 standoff $r에 섰다');
    final angles = {for (final p in settled) (math.atan2(p.dy, p.dx) * 100).round()};
    expect(angles.length, lessThanOrEqualTo(2), reason: '돌지 않는다(같은 자리)');
    // 화면 안: 보스 중심이 배 위쪽, 옆으로 화면 반폭(viewWidth/2)을 넘지 않는다.
    for (final p in settled) {
      expect(p.dy, lessThan(0));
      expect(p.dx.abs(), lessThan(top.number('viewWidth') / 2));
    }
  });

  test('보통 보스는 그대로 원을 돈다(배율 ≤ orbitMax)', () {
    const stage = 7; // 순환 보스
    final id = t.regions.bossAt(stage).id;
    expect(t.regions.bossClassOf(id), 'other');
    final r = bossStandoffFor(t, id);
    final settled = fight(stage, 20).where((p) => (math.sqrt(p.dx * p.dx + p.dy * p.dy) - r).abs() < 1).toList();
    final angles = {for (final p in settled) (math.atan2(p.dy, p.dx) * 100).round()};
    expect(angles.length, greaterThan(10));
  });
}

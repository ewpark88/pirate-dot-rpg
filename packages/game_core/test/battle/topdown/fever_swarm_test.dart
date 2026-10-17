import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 피버 무리 (사용자 폰 피드백 2026-10-17 '피버 때 몬스터가 2~3배로 몰려와야 한다', meta.fever.swarm).
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11);

  ({Field f, List<Foe> foes}) wave(int stage, {required bool fever}) {
    final f = Field(stage: stage, shipHpMax: BigNum.one, shipHp: BigNum.one)
      ..geometry = geometryFor(t, stage)
      ..feverSwarm = feverSwarmPattern(t, fever: fever);
    final ctx = SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(3), onEvent: (_) {});
    f.geometryOr(t.waves).spawnWave(f, stage, ctx, kind: 'crab');
    return (f: f, foes: f.foes);
  }

  test('마리 = 평소 × countMul(상한 max) — 스테이지 1은 60 → 150, 높은 스테이지는 200에서 멈춤', () {
    final sw = t.meta.raw.obj('fever').obj('swarm');
    expect(feverSwarmCount(t, 1), (t.waves.topMobCountAt(1) * sw.number('countMul')).round());
    expect(feverSwarmCount(t, 9999), sw.integer('max'));
    expect(wave(20, fever: true).foes, hasLength(feverSwarmCount(t, 20)));
    expect(wave(20, fever: false).foes, hasLength(t.waves.topMobCountAt(20)));
  });

  test('파 총량(HP·골드·공격)은 그대로 — 한 마리가 약해질 뿐', () {
    BigNum sum(List<Foe> xs, BigNum Function(Foe) f) => xs.fold(BigNum.zero, (a, e) => a + f(e));
    final on = wave(20, fever: true).foes;
    final off = wave(20, fever: false).foes;
    for (final f in <BigNum Function(Foe)>[(e) => e.maxHp, (e) => e.gold, (e) => e.attack]) {
      expect(sum(on, f).closeTo(sum(off, f)), isTrue);
    }
    expect((on.first.maxHp / off.first.maxHp).toDouble(), lessThan(0.5));
  });

  test('사방에서 한꺼번에(ring): 네 방향 모두, 대부분 바로 나온다(가까이 등장 위협은 그대로)', () {
    final w = wave(20, fever: true);
    final top = (w.f.geometry! as TopGeometry).top;
    final quadrants = {
      for (final e in w.foes) ((math.atan2(e.y - top.shipY, e.x - top.shipX) + math.pi) / (math.pi / 2)).floor() % 4,
    };
    expect(quadrants, hasLength(4));
    expect(w.foes.where((e) => e.holdSec == 0).length, greaterThan(w.foes.length * 0.6));
  });
}

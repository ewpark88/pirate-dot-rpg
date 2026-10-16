import 'dart:convert';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_fever.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 피버 좌우 이동 (사용자 지시 '피버 때 배가 고정으로 있지 않고 좌우로 멋지게', meta.fever.weave).
void main() {
  final start = DateTime.utc(2026, 11);
  const stage = 20;
  const amp = 60.0;
  const period = 2.0;

  GameTables withWeave({bool on = true}) {
    final raw = Map<String, String>.of(rawTables);
    final meta = jsonDecode(raw['meta']!) as Map<String, dynamic>;
    final fever = meta['fever'] as Map<String, dynamic>;
    if (on) {
      fever['weave'] = {'amp': amp, 'periodSec': period};
    } else {
      fever.remove('weave');
    }
    raw['meta'] = jsonEncode(meta);
    return GameTables.load(raw);
  }

  final t = withWeave();
  final dt = t.waves.tickMs / 1000;
  GameState state(int feverLeft) => GameState.newGame(playerId: 'w', seed: 4, now: start).copyWith(
    progress: const Progress(stage: stage, bestStage: stage),
    battle: BattleView.empty.copyWith(feverTicksLeft: feverLeft),
  );

  test('S자: 진폭 안, 반 주기 뒤 최대(±amp), 시작·끝은 부드럽게(0에서), 피버 아니거나 키 없으면 0', () {
    final quarter = (period / 4 / dt).round();
    final long = state(10000);
    expect(feverWeave(long, t, 0), 0);
    expect(feverWeave(long, t, 1).abs(), lessThan(amp * 0.05), reason: '시작은 천천히');
    final peak = (period * 1.25 / dt).round(); // 반 주기 ease가 끝난 뒤 첫 마루
    expect(feverWeave(long, t, peak), closeTo(amp, 1e-6));
    expect(feverWeave(long, t, peak + 2 * quarter), closeTo(-amp, 1e-6));
    for (var i = 0; i < 400; i++) {
      expect(feverWeave(long, t, i).abs(), lessThanOrEqualTo(amp + 1e-9));
    }
    expect(feverWeave(state(1), t, peak).abs(), lessThan(amp * 0.05), reason: '끝도 부드럽게');
    expect(feverWeave(state(0), t, peak), 0, reason: '피버 아님');
    expect(feverWeave(long, withWeave(on: false), peak), 0, reason: '키 없음');
  });

  test('배가 옮기면 전장 모양이 모두 따라간다(캡슐·사거리), 카메라 사각형은 그대로', () {
    final g = geometryFor(t, stage) as TopGeometry;
    final x0 = g.top.shipX;
    final probe = Foe(
      id: 1,
      kind: 'crab',
      layer: 'surface',
      x: x0 + 40,
      y: g.top.shipY,
      maxHp: BigNum.one,
      speed: 0,
      attack: BigNum.one,
      gold: BigNum.one,
    );
    final gap0 = g.hullGap(probe.x, probe.y);
    g.weave(30);
    expect(g.top.shipX, x0 + 30);
    expect(g.ship.x, x0 + 30);
    expect(g.viewShip.x, x0 + 30);
    expect(g.hullGap(probe.x, probe.y), closeTo(gap0 - 30, 1e-9));
    final edge = Foe(
      id: 2,
      kind: 'crab',
      layer: 'surface',
      x: x0 - g.top.viewWidth / 2 + 1,
      y: g.top.shipY,
      maxHp: BigNum.one,
      speed: 0,
      attack: BigNum.one,
      gold: BigNum.one,
    );
    expect(g.onScreen(edge), isTrue, reason: '카메라는 바다 가운데 그대로');
    g.weave(0);
    expect(g.top.shipX, x0);
  });

  test('엔진: 피버 중 BattleView.shipX가 좌우로 움직이고, 끝나면 가운데로 — 같은 시드는 같다', () {
    List<double> xs(GameTables tables) {
      final e = CoreEngine(
        tables: tables,
        clock: ManualClock(start),
        initial: state((4 / dt).round()).copyWith(crews: const {'octo': CrewState()}),
      );
      final out = <double>[];
      for (var i = 0; i < (6 / dt).round(); i++) {
        e.tick();
        out.add(e.state.battle!.shipX!);
      }
      return out;
    }

    final a = xs(t);
    final center = (geometryFor(t, stage) as TopGeometry).base.shipX;
    final spread = a.map((x) => (x - center).abs()).reduce(math.max);
    expect(spread, greaterThan(amp * 0.8), reason: '좌우로 크게');
    expect(spread, lessThanOrEqualTo(amp + 1e-6));
    expect(a.last, center, reason: '피버가 끝나면 가운데');
    expect(xs(t), a);
    expect(xs(withWeave(on: false)).every((x) => x == center), isTrue, reason: '키 없으면 고정');
  });

  group("지그재그(사용자 지시 '지그재그로 대각선'·'조금 더 느리게')", () {
    const leg = 2.0;
    const turn = 0.45;
    const surge = 8.0;
    const tilt = 25.0;
    final zt = () {
      final raw = Map<String, String>.of(rawTables);
      final meta = jsonDecode(raw['meta']!) as Map<String, dynamic>;
      (meta['fever'] as Map<String, dynamic>)['weave'] = {
        'mode': 'zigzag',
        'amp': 70,
        'legSec': leg,
        'turnSec': turn,
        'surge': surge,
        'tiltDeg': tilt,
      };
      raw['meta'] = jsonEncode(meta);
      return GameTables.load(raw);
    }();
    final long = state(100000);
    final poses = [for (var i = 0; i < (20 / dt).round(); i++) feverPose(long, zt, i)];

    test('꼭짓점 ±70, 다리 동안 일정 속도(곧은 선), 꺾을 때만 속도가 바뀐다', () {
      expect(poses.map((p) => p.x).reduce(math.max), closeTo(70, 0.5));
      expect(poses.map((p) => p.x).reduce(math.min), closeTo(-70, 0.5));
      // ease가 끝난 뒤 한 다리 안: 틱마다 x 변화가 같다
      final from = (4 / dt).round();
      final steps = [for (var i = from; i < from + 60; i++) poses[i + 1].x - poses[i].x];
      final straight = steps.where((d) => (d - steps.first).abs() < 1e-9).length;
      expect(straight, greaterThan(20), reason: '곧은 구간이 길다');
    });

    test('앞뒤로 surge만큼(앞 = y 음수), 기울기는 ±25°(이동 방향), 꺾는 꼭짓점에선 0', () {
      final ys = poses.map((p) => p.y);
      expect(ys.reduce(math.min), closeTo(-surge, 0.2));
      expect(ys.reduce(math.max), lessThanOrEqualTo(1e-9));
      final hs = poses.map((p) => p.heading);
      expect(hs.reduce(math.max), closeTo(tilt * math.pi / 180, 1e-6));
      expect(hs.reduce(math.min), closeTo(-tilt * math.pi / 180, 1e-6));
      final peak = poses.indexWhere((p) => p.x > 69.5);
      expect(poses[peak].heading.abs(), lessThan(0.1), reason: '꼭짓점에서 꺾는 중');
    });

    test('왕복이 사인 2.5초보다 느긋하다(왕복 = 2 × (2.0 + 0.45)초), 처음은 가운데에서 부드럽게', () {
      expect(poses.first.x, 0);
      expect(poses[1].x.abs(), lessThan(0.5));
      final ups = <int>[];
      for (var i = 1; i < poses.length; i++) {
        if (poses[i - 1].x < 69.5 && poses[i].x >= 69.5) ups.add(i);
      }
      expect((ups[1] - ups[0]) * dt, closeTo(2 * (leg + turn), dt * 2));
    });

    test('엔진: 피버 중 BattleView.shipHeading이 기울고 shipY가 앞뒤로, 끝나면 0', () {
      final e = CoreEngine(
        tables: zt,
        clock: ManualClock(start),
        initial: state((6 / dt).round()).copyWith(crews: const {'octo': CrewState()}),
      );
      final hs = <double>[];
      final ys = <double>{};
      for (var i = 0; i < (8 / dt).round(); i++) {
        e.tick();
        hs.add(e.state.battle!.shipHeading);
        ys.add(e.state.battle!.shipY!);
      }
      expect(hs.map((h) => h.abs()).reduce(math.max), greaterThan(0.3));
      expect(ys.length, greaterThan(3));
      expect(hs.last, 0);
    });
  });
}

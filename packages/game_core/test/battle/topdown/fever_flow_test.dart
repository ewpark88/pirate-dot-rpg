import 'dart:math' as math;

import 'package:game_core/src/battle/topdown/top_fever_flow.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 피버 배 모션 'flow' (사용자 피드백 #24 — 매끈한 곡선·가감속·드리프트·가끔 작은 원).
void main() {
  final t = GameTables.load();
  final w = t.meta.raw.obj('fever').obj('weave');
  final dt = t.waves.tickMs / 1000;
  final view = t.waves.raw.obj('top');
  final halfW = view.number('viewWidth') / 2;
  List<({double x, double y, double heading})> run(double seconds) => [
    for (var i = 0; i * dt <= seconds; i++) flowPose(w, i * dt, 1, dt),
  ];

  test('표는 flow, 시작 자리는 가운데 · ease 0이면 가만히', () {
    expect(w.raw['mode'], 'flow');
    expect(flowPose(w, 0, 1, dt).x, closeTo(0, 1e-9));
    final still = flowPose(w, 1.3, 0, dt);
    expect((still.x, still.y, still.heading), (0.0, 0.0, 0.0));
  });

  test('매끈하다: 틱마다 옮김이 작고 속도가 갑자기 꺾이지 않는다(지그재그와 달리)', () {
    final p = run(w.number('periodSec') * 4);
    var maxJerk = 0.0;
    for (var i = 2; i < p.length; i++) {
      final v1 = (x: p[i - 1].x - p[i - 2].x, y: p[i - 1].y - p[i - 2].y);
      final v2 = (x: p[i].x - p[i - 1].x, y: p[i].y - p[i - 1].y);
      expect(math.sqrt(v2.x * v2.x + v2.y * v2.y), lessThan(w.number('amp') * 0.2), reason: '틱 $i');
      maxJerk = math.max(maxJerk, math.sqrt(math.pow(v2.x - v1.x, 2) + math.pow(v2.y - v1.y, 2)));
    }
    expect(maxJerk, lessThan(1.0)); // 매끈한 S자 — 지그재그처럼 꺾이면 훨씬 크다
  });

  test('가감속: 가운데에서 가장 빠르고 가장자리에서 느리다', () {
    final period = w.number('periodSec');
    double speed(double s) {
      final a = flowPose(w, s - dt, 1, dt);
      final b = flowPose(w, s + dt, 1, dt);
      return (b.x - a.x).abs() / (2 * dt);
    }

    expect(speed(0), greaterThan(speed(period / 4 - 0.15) * 2)); // 첫 바퀴(원 돌기 없음) 오른쪽 끝 근처
  });

  test('화면 안 · 원 돌기 없음(사용자: 360도 돌면서 촐싹맞다) · 기울기는 늘 tiltDeg(15°) 이하', () {
    final p = run(w.number('periodSec') * 3);
    expect(p.map((e) => e.x.abs()).reduce(math.max) + t.waves.top.shipRadius, lessThan(halfW));
    final tilt = w.number('tiltDeg') * math.pi / 180;
    expect(w.number('tiltDeg'), lessThanOrEqualTo(15));
    expect(p.every((e) => e.heading.abs() <= tilt + 1e-9), isTrue);
    expect(w.numberOr('loopEvery', 0), 0);
  });
}

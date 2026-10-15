import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/proto/proto_sim.dart';

ProtoSim run(int seed, double seconds) {
  final s = ProtoSim(seed: seed);
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    s.step(1 / 60);
  }
  return s;
}

void main() {
  test('결정론: 같은 시드면 같은 판', () {
    final a = run(7, 60);
    final b = run(7, 60);
    expect((a.kills, a.gold, a.enemies.length, a.ship.x), (b.kills, b.gold, b.enemies.length, b.ship.x));
    expect(run(8, 60).kills, isNot(a.kills));
  });

  test('적은 최대 150마리를 넘지 않는다', () {
    final s = ProtoSim(seed: 3);
    var most = 0;
    for (var t = 0.0; t < ProtoSim.duration; t += 1 / 60) {
      s.step(1 / 60);
      if (s.enemies.length > most) most = s.enemies.length;
    }
    expect(most, lessThanOrEqualTo(ProtoSim.maxEnemies));
    expect(most, greaterThan(60)); // 끝으로 갈수록 화면이 꽉 찬다
  });

  test('파도가 점점 세진다: 마지막 1분 처치 > 첫 1분 처치, 배 강화 단계 6(30초마다)', () {
    final s = ProtoSim(seed: 5);
    var at60 = 0;
    var at120 = 0;
    for (var t = 0.0; t < ProtoSim.duration; t += 1 / 60) {
      s.step(1 / 60);
      if (at60 == 0 && s.time >= 60) at60 = s.kills;
      if (at120 == 0 && s.time >= 120) at120 = s.kills;
    }
    expect(s.kills - at120, greaterThan(at60));
    expect(s.powerLevel, 6);
    expect(s.over, isTrue);
  });

  test('배는 늘 화면 안, 세계는 위로 흐른다', () {
    final s = ProtoSim(seed: 9);
    for (var t = 0.0; t < 90; t += 1 / 60) {
      s.step(1 / 60);
      expect((s.ship.x - s.camX).abs(), lessThanOrEqualTo(s.viewWidth / 2));
      expect((s.ship.y - s.camY).abs(), lessThanOrEqualTo(s.viewHeight / 2));
    }
    expect(s.camY, lessThan(-1000)); // 90초 × 14도트/초 위로
  });

  test('세 계열이 모두 피해를 준다(폭발·광선·충격 연출이 생긴다)', () {
    final s = ProtoSim(seed: 11);
    final seen = <FxKind>{};
    for (var t = 0.0; t < 20; t += 1 / 60) {
      s.step(1 / 60);
      seen.addAll(s.fx.map((f) => f.kind));
    }
    expect(seen, containsAll([FxKind.blast, FxKind.beam, FxKind.ring, FxKind.pop]));
    expect(s.gold, greaterThan(0));
  });

  test('성능: 150마리 근처에서 한 걸음 평균 2ms 미만(60fps 예산 16.7ms 중)', () {
    final s = ProtoSim(seed: 13);
    for (var t = 0.0; t < 170; t += 1 / 60) {
      s.step(1 / 60);
    }
    final sw = Stopwatch()..start();
    const n = 300;
    for (var i = 0; i < n; i++) {
      s.step(1 / 60);
    }
    final avgMs = sw.elapsedMicroseconds / n / 1000;
    // 측정값을 남긴다(기기 성능과 비교용).
    // ignore: avoid_print
    print('proto sim step avg ${avgMs.toStringAsFixed(3)}ms with ${s.enemies.length} enemies');
    expect(avgMs, lessThan(2));
  });
}

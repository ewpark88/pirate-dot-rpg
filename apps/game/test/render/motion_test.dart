import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';

import 'helpers.dart';
import 'top_recording.dart';

/// 모션 v1 (사용자 '움직임이 자연스럽고 매끄럽게, 뚝뚝 끊김 0'): 20Hz 엔진 틱 사이를 렌더가 잇는다.
void main() {
  test('배 자리·방향이 화면 프레임마다 이어진다(틱마다 계단처럼 멈췄다 뛰지 않음)', () {
    final rec = topRecording(noHordeTables, ticks: 520, fever: 0.99); // 첫 파 대군 습격은 뺀다(배 경로 타이밍)
    final scene = BattleScene(noHordeTables, rec, loop: false);
    while (scene.player.position < 120) {
      // 피버(12초) 한가운데 — 직선 순항의 방향 전환(잠깐 정지)을 피해
      scene.update(kFrameMs);
    }
    var prev = scene.topShip;
    final steps = <double>[];
    for (var i = 0; i < 12; i++) {
      scene.update(kFrameMs);
      final s = scene.topShip;
      steps.add((s - prev).distance);
      prev = s;
    }
    // 움직이는 동안 멈춘 프레임이 없고, 가장 큰 걸음이 가장 작은 걸음의 3배를 넘지 않는다.
    final moving = steps.where((d) => d > 0).toList();
    expect(moving.length, steps.length, reason: '틱 사이 프레임에 배가 멈추면 안 된다: $steps');
    final mx = moving.reduce((a, b) => a > b ? a : b);
    final mn = moving.reduce((a, b) => a < b ? a : b);
    expect(mx / mn, lessThan(3), reason: '$steps');
  });

  test('방향 보간은 가까운 쪽으로(−π↔π를 넘을 때 반대로 돌지 않음)', () {
    expect(lerpAngle(3, -3, 0.5), closeTo(3.0 + 0.1416, 1e-3));
    expect(lerpAngle(0, 1, 0.5), 0.5);
  });
}

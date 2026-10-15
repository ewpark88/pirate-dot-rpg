import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/demo/sample_battle.g.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/viewport/battle_frame.dart';

import 'helpers.dart';

/// 화면 밖(보이는 오른쪽 끝 너머) 목표로 날아가는 발사체가 몇 개인가 (S1: '적이 보이는 곳에서만 쏜다').
/// 엔진 사거리(S2 attack.reach ≤ waves.field.visibleRight 266)가 들어오면 0이어야 한다.
int offscreenShots(List<RecordedTick> rec, BattleFrame layout) {
  final s = BattleScene(tables, rec)..layout = layout;
  final seen = <Object>{};
  var out = 0;
  for (var f = 0; f < rec.length * 4; f++) {
    s.update(1000 / 60);
    for (final p in s.projectiles.active) {
      if (p.progress <= 0 || !seen.add(p)) continue;
      if (p.toX > layout.visibleRight) out++;
    }
  }
  return out;
}

void main() {
  test('데모 기록: 화면 밖 목표 발사체 수 (사거리 들어오기 전 기록이면 기록만 남긴다)', () {
    final n = offscreenShots(decodeRecording(sampleBattleJsonl), battleFrameFor(const Size(384, 374), 2.8125));
    // 측정값을 남긴다(사거리 전후 비교용).
    // ignore: avoid_print
    print('화면 밖 목표 발사체: $n');
    expect(n, isNonNegative);
  });
}

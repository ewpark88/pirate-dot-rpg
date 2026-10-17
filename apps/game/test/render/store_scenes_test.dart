import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';
import 'store_scenes.dart';
import 'top_recording.dart';

/// 스토어 2차 장면 도우미: 고른 순간에 렌더 연출이 실제로 화면에 있다(필살기 진행 중·보스 등장 끝).
void main() {
  final s = StoreScenes(tables);

  test('필살기 정점은 필살기 연출(1.1초) 안, 보스 등장 정착은 등장 연출(1.2초) 뒤', () {
    expect(s.ultimatePeak * tables.waves.tickMs, lessThan(1100));
    expect(s.bossSettled * tables.waves.tickMs, greaterThanOrEqualTo(1200));
    final (a, b) = s.hordeWindow;
    expect(b * tables.waves.tickMs, lessThan(1500), reason: '대군 띠(1.5초)가 떠 있는 동안');
    expect(a, lessThan(b));
  });

  test('보스 등장 정착 틱에 등장 연출이 끝나 있다', () {
    final rec = topRecording(noHordeTables, ticks: 80, stage: 120, bossAt: 5);
    final at = rec.indexWhere((t) => t.events.any((e) => e is BossSpawned));
    final scene = BattleScene(tables, rec.sublist(0, at + s.bossSettled + 1), loop: false);
    while (scene.player.position < at + s.bossSettled) {
      scene.update(kFrameMs);
    }
    expect(scene.moments.entryMs, lessThanOrEqualTo(0));
    expect(s.onScreen(rec[at + s.bossSettled].frame), greaterThan(0));
  });
}

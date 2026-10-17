import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';
import 'top_recording.dart';

// 사용자 버그 '몬스터가 다가오다 가까운 놈부터 뒤에 있는 놈까지 전부 멈춘다' 회귀 테스트.
// 원인: 탑다운 그리기가 poseCount를 무시하고 지난 파의 옛 적 자리를 그렸다(파가 끝나 적이 0이어도 그대로 → 멈춘 듯). + 잦은 히트스톱.
// 라이브(엔진 push) 재생: 엔진 틱 50ms마다 push, 렌더 16.7ms마다 update. 보이는 적이 전부 그대로인 프레임 비율·가장 긴 구간.
void main() {
  test('라이브 재생: 보이는 적 전부 정지는 히트스톱 정도로 짧다(엔진이 움직였는데 화면이 전부 멈춘 프레임: 가장 긴 구간 2프레임 이하, 1% 미만)', () {
    final rec = topRecording(noHordeTables, ticks: 800, stage: 23); // 첫 파 대군 습격은 뺀다(고리가 화면 밖에서 모여드는 첫 몇 초)
    final s = BattleScene(noHordeTables, null);
    var pushed = 0;
    var engineMs = 0.0;
    var allStill = 0;
    var frames = 0;
    var runs = 0;
    var run = 0;
    var longest = 0;
    var prev = <int, (double, double)>{};
    for (var t = 0.0; t < 30000; t += kFrameMs) {
      while (engineMs <= t && pushed < rec.length) {
        s.push(rec[pushed++]);
        engineMs += 50;
      }
      s.update(kFrameMs);
      final now = {for (var k = 0; k < s.poseCount; k++) s.poses[k].id: (s.poses[k].drawX, s.poses[k].drawY)};
      if (t > 3000 && now.isNotEmpty) {
        frames++;
        // 엔진이 이 구간(i → i+1)에서 적을 하나라도 움직였는데 화면은 전부 그대로인 프레임만 센다
        // (히트스톱 틱·배에 붙어 공격 중인 적처럼 엔진이 세운 것은 렌더 잘못이 아니다).
        final i = s.player.position.floor();
        final engineMoved = i + 1 < rec.length && _moved(rec[i].frame.enemies, rec[i + 1].frame.enemies);
        final still = engineMoved && now.entries.every((e) => prev[e.key] == e.value);
        if (still) {
          allStill++;
          run++;
          if (run > longest) longest = run;
        } else {
          if (run > 0) runs++;
          run = 0;
        }
      }
      prev = now;
    }
    expect(longest, lessThanOrEqualTo(2), reason: '멈춤 구간 $runs번, 버퍼 ${s.player.bufferedTicks}');
    expect(allStill / frames, lessThan(0.01));
  });
}

bool _moved(List<EnemyView> a, List<EnemyView> b) {
  for (final e in b) {
    for (final p in a) {
      if (p.id == e.id && ((p.x - e.x).abs() > 0.01 || (p.y - e.y).abs() > 0.01)) return true;
    }
  }
  return false;
}

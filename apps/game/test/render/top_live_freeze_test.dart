import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

import 'helpers.dart';
import 'top_recording.dart';

// 사용자 버그 '몬스터가 다가오다 가까운 놈부터 뒤에 있는 놈까지 전부 멈춘다' 회귀 테스트.
// 원인: 탑다운 그리기가 poseCount를 무시하고 지난 파의 옛 적 자리를 그렸다(파가 끝나 적이 0이어도 그대로 → 멈춘 듯). + 잦은 히트스톱.
// 라이브(엔진 push) 재생: 엔진 틱 50ms마다 push, 렌더 16.7ms마다 update. 보이는 적이 전부 그대로인 프레임 비율·가장 긴 구간.
void main() {
  test('라이브 재생: 보이는 적 전부 정지는 히트스톱 정도로 짧다(가장 긴 구간 15프레임 이하, 8% 미만)', () {
    final rec = topRecording(tables, ticks: 800, stage: 23);
    final s = BattleScene(tables, null);
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
        final still = now.entries.every((e) => prev[e.key] == e.value);
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
    expect(longest, lessThanOrEqualTo(15), reason: '멈춤 구간 $runs번, 버퍼 ${s.player.bufferedTicks}');
    expect(allStill / frames, lessThan(0.08)); // 남는 건 엔진 히트스톱(약 5%, 한 번에 1~2틱)
  });
}

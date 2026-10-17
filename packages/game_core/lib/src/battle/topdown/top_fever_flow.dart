import 'dart:math' as math;

import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

/// 피버 배 모션 'flow'(사용자 피드백 #24 '피버 때 배 움직임이 별로 — 자연스럽고 활기차게', 피버 v2 — 몰려온 무리 사이를 가르며):
/// 꺾이는 지그재그 대신 매끈한 8자(S자) 곡선 — x = amp·sin(u), y = −ampY·sin(2u)(가로지를 때 앞으로 치고 나갔다 돌아옴).
/// 속도는 사인이라 가장자리에서 느려지고(감속) 가운데서 가장 빠르다(가속). loopEvery 바퀴마다 오른쪽 끝에서 반지름 loopRadius 원을
/// loopSec 동안 가운데 쪽으로 한 바퀴 돈다(가끔 작은 원 돌기 — 화면 밖으로 안 나감). 기울기 = 진행 방향(화면 위 = 0) × drift(방향 바꿀 때 살짝 더 크게 휘는 드리프트),
/// 최대 tiltDeg — 원을 도는 동안은 한 바퀴 그대로 돈다.
/// [sec]은 피버 시작 뒤 초, [ease]는 시작·끝 0 → 1, [dt]는 한 틱 초(진행 방향 차분). 반환은 바다 가운데에서 옮긴 값.
({double x, double y, double heading}) flowPose(JsonReader w, double sec, double ease, double dt) {
  final amp = w.number('amp');
  final ampY = w.numberOr('ampY', 0);
  final period = w.number('periodSec');
  final tilt = w.numberOr('tiltDeg', 0) * radiansPerDegree;
  final drift = w.numberOr('drift', 1);
  ({double x, double y, double loopAngle}) at(double s) {
    final u = fullTurn * s / period;
    var x = amp * math.sin(u);
    var y = -ampY * math.sin(u + u);
    var loop = 0.0;
    final every = w.numberOr('loopEvery', 0).round();
    if (every > 0) {
      // every 바퀴째의 오른쪽 끝(u = π/2) 둘레 loopSec 동안: 반지름 R 원을 한 바퀴(부드럽게 출발·도착).
      final loopSec = w.number('loopSec');
      final r = w.number('loopRadius');
      final cycle = (s / period).floor();
      final peak = (cycle + half * half) * period; // 그 바퀴의 오른쪽 끝
      final into = s - (peak - loopSec * half);
      if (cycle % every == every - 1 && into >= 0 && into <= loopSec) {
        final p = into / loopSec;
        loop = fullTurn * (1 - math.cos(math.pi * p)) * half; // 천천히 들어가 빠르게 돌고 천천히 나온다
        // 중심을 가운데 쪽 r에 둔 원 — 늘 그 자리보다 안쪽이라 화면 밖으로 안 나간다
        x -= r * (1 - math.cos(loop));
        y -= r * math.sin(loop);
      }
    }
    return (x: x, y: y, loopAngle: loop);
  }

  final a = at(sec - dt); // 진행 방향(속도)을 앞뒤 한 틱 차분으로
  final b = at(sec + dt);
  final now = at(sec);
  final vx = (b.x - a.x) / (dt + dt);
  final vy = (b.y - a.y) / (dt + dt);
  // 바다가 아래로 흐르므로(배는 늘 앞으로 나아감) 앞쪽 기본 속도를 더해 방향을 잡는다 — 가만히 있을 때 0(위).
  final forward = fullTurn * amp / period;
  var heading = math.atan2(vx, forward - vy) * drift;
  heading = heading.clamp(-tilt, tilt) + now.loopAngle;
  return (x: now.x * ease, y: now.y * ease, heading: heading * ease);
}

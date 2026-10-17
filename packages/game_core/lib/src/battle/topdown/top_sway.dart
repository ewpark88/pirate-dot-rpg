import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_field.dart';
import 'package:game_core/src/engine/units.dart';

/// standoff 원에 닿은 보스(기절·돌진 중 빼고)를 원을 따라 옮긴다 — [place](적, 배 기준 각도, 반지름).
void orbitBosses(TopField top, List<Foe> foes, double dt, void Function(Foe, double, double) place) {
  for (final b in foes) {
    if (!b.standsOff || !b.alive || b.stunned || (b.plan?.steering ?? false)) continue;
    final dx = b.x - top.shipX;
    final dy = b.y - top.shipY;
    final r = top.standoffOf(b);
    if (math.sqrt(dx * dx + dy * dy) > r + 1) continue;
    final a = bossOrbitAngle(top, b, math.atan2(dy, dx), dt);
    if (a != null) place(b, a, r);
  }
}

/// standoff 원에 선 보스의 다음 각도([angle] = 배 기준 지금 각도, 라디안). 원을 돌면(배율 ≤ orbitMax) 원 돌기 속도로,
/// 큰 보스(배율 > orbitMax — 대보스 그림이 화면 폭에 가까워 옆으로 돌면 화면 밖)는 배 위쪽 ±swayDeg 호를 같은 각속도로 오간다
/// (끝에서 방향을 바꿈 — 가만히 서면 탄이 다 맞아 보스전이 짧아진다, waves.top.bossScale). swayDeg 0이면 제자리(null).
double? bossOrbitAngle(TopField top, Foe b, double angle, double dt) {
  final step = top.bossOrbitDegPerSec * radiansPerDegree * dt;
  if (top.orbits(b)) return angle + step;
  final arc = top.swayDeg * radiansPerDegree;
  if (arc <= 0) return null;
  const up = -math.pi * half;
  final a = angle + step * b.swayDir;
  if ((a - up).abs() < arc) return a;
  b.swayDir = -b.swayDir;
  return up + arc * (a > up ? 1 : -1);
}

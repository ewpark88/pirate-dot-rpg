import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/battle/topdown/top_spawn.dart';

/// 장면 무리(탑·요일 던전)를 카메라 테두리 바로 밖(+ spawnMargin + 몸 반경)에서 출발시킨다 — 방향·대열 깊이는 그대로.
/// 예전엔 배 쪽으로 spawnDistanceMul 0.55배 당겨 위·아래 방향(화면 반높이 160 > 113)은 화면 안에서 생겼다(S1 실기기 10-17).
/// 가까이 등장(배 둘레에서 솟아오름 — nearX)은 자기 자리가 따로라 건드리지 않는다.
void sceneSpawnAtView(Field f, int before) {
  final g = f.geometry;
  if (g is! TopGeometry) return;
  final top = g.base;
  final spawn = TopSpawn(top, 0);
  for (final e in f.foes.skip(before)) {
    if (e.nearX != null || e.boss) continue;
    final dx = e.x - top.shipX;
    final dy = e.y - top.shipY;
    final a = math.atan2(dy, dx);
    final d = math.sqrt(dx * dx + dy * dy);
    final depth = math.max<double>(0, d - spawn.startDistance(e, a)); // 대열 뒷줄·흩뿌림 거리
    spawn.place(e, a, spawn.toView(a) + top.spawnMargin + top.radiusOf(e) + depth);
  }
}

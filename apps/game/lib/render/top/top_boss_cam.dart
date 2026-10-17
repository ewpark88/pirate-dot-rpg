import 'dart:math' as math;

import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

/// 보스전 카메라(사용자 '보스전이 박진감 넘치게' + 실기기 s05 '보스전에 배가 작아 보인다'): 0.6초에 걸쳐 배를 화면 아래
/// [shipAt]로 당기고, 배와 보스(그림 반지름 포함)가 보이는 전장 높이의 [fit] 안에 꽉 차게 줌(1.0~[maxZoom]). 등장 순간 줌 펀치.
class TopBossCam {
  static const shipAt = 0.74;
  static const fit = 0.58;
  static const maxZoom = 1.6;

  double blend = 0; // 0 평소 ~ 1 보스전
  double _zoom = 1;
  bool _was = false;
  double _punchAt = -1000000000;

  /// 이번 프레임 (줌, 배 화면 y 목표). [bossR] = 보스 그림 반지름(단위, TopEnemies.radiusOf).
  (double, double) update(
    BattleScene scene,
    TopFrame frame,
    double now,
    double dt,
    double Function(EnemyPose e) bossR,
  ) {
    final boss = scene.frame.bossActive;
    if (dt > 0) blend += ((boss ? 1 : 0) - blend) * math.min(1, dt / 200);
    if (boss && !_was) _punchAt = now;
    _was = boss;
    // 배 ↔ 가장 먼 보스 위쪽 끝까지 단위 거리 → 그만큼이 fit 안에 들어오는 줌
    var span = 0.0;
    final ship = scene.topShip;
    for (var k = 0; k < scene.poseCount; k++) {
      final e = scene.poses[k];
      if (!e.boss) continue;
      span = math.max(span, (ship.dy - e.drawY).abs() + bossR(e) + 30);
    }
    final want = span <= 0 ? 1.0 : (fit * frame.fieldDp.height / (span * frame.dot)).clamp(1.0, maxZoom);
    if (dt > 0) _zoom += (want - _zoom) * math.min(1, dt / 400);
    final punchT = (now - _punchAt) / 300;
    final punch = punchT >= 0 && punchT < 1 ? 0.06 * (1 - punchT) * (1 - punchT) : 0.0;
    final zoom = 1 + (_zoom - 1) * blend + punch;
    final y = frame.shipScreen.dy + (shipAt - TopFrame.kShipAt) * frame.fieldDp.height * blend;
    return (zoom, y);
  }
}

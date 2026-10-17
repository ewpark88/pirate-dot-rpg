import 'dart:math' as math;

import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

/// 보스전 카메라(사용자 '보스전이 박진감 넘치게' + '배·보스가 가끔 너무 줌인돼 화면에 잘린다'): 0.6초에 걸쳐 배를 화면 아래
/// [shipAt]로 당기고, 배와 보스가 **잘리지 않는 한** 크게 줌(1.0~[maxZoom]).
/// 잘림 판정 = 보스 그림 반지름 + 위 여백(체력 막대·이름표·흔들림 [_topPad]) · 옆 여백, 화면 가장자리 [_edgeDp] 이상.
/// 보스가 돌진·호를 오가도 잘리지 않게 최근 [_holdMs] 동안 가장 먼 자리 기준, 줌 아웃은 빠르게·줌 인은 천천히 따라간다.
class TopBossCam {
  static const shipAt = 0.72;
  static const maxZoom = 1.3;
  static const _edgeDp = 14.0;
  static const _topPad = 22.0; // 단위: 체력 막대·브레이크 게이지·이름표·흔들림
  static const _sidePad = 8.0;
  static const _shipR = 34.0; // 배 그림 + 착탄 여유(단위)
  static const _holdMs = 1500.0;

  double blend = 0; // 0 평소 ~ 1 보스전
  double _zoom = 1;
  bool _was = false;
  double _punchAt = -1000000000;
  double _up = 0; // 배 위로 가장 먼 보스 위 끝(단위, 최근 hold)
  double _side = 0; // 배 좌우로 가장 먼 보스 옆 끝
  double _heldAt = -1000000000;

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
    final ship = scene.topShip;
    var up = 0.0;
    var side = 0.0;
    for (var k = 0; k < scene.poseCount; k++) {
      final e = scene.poses[k];
      if (!e.boss) continue;
      final r = bossR(e);
      up = math.max(up, ship.dy - e.drawY + r + _topPad);
      side = math.max(side, (e.drawX - ship.dx).abs() + r + _sidePad);
    }
    // 최근 가장 먼 자리를 잠깐 붙든다(돌진·호 왕복에도 줌이 들쑥날쑥하지 않게)
    if (up >= _up || side >= _side || now - _heldAt > _holdMs || now < _heldAt) {
      _up = math.max(up, now - _heldAt > _holdMs || now < _heldAt ? 0 : _up);
      _side = math.max(side, now - _heldAt > _holdMs || now < _heldAt ? 0 : _side);
      _heldAt = now;
    }
    final field = frame.fieldDp;
    final d = frame.dot;
    // 잘리지 않는 최대 줌: 위(배 위 shipAt 만큼), 아래(배 아래), 옆(가운데에서 반 폭)
    var fit = maxZoom;
    if (_up > 0) fit = math.min(fit, (field.height * shipAt - _edgeDp) / (_up * d));
    fit = math.min(fit, (field.height * (1 - shipAt) - _edgeDp) / (_shipR * d));
    if (_side > 0) fit = math.min(fit, (field.width / 2 - _edgeDp) / (_side * d));
    final want = fit.clamp(0.8, maxZoom);
    if (dt > 0) _zoom += (want - _zoom) * math.min(1, dt / (want < _zoom ? 120 : 500));
    final punchT = (now - _punchAt) / 300;
    final punch = punchT >= 0 && punchT < 1 ? 0.04 * (1 - punchT) * (1 - punchT) : 0.0;
    final zoom = 1 + (_zoom - 1) * blend + punch;
    final y = frame.shipScreen.dy + (shipAt - TopFrame.kShipAt) * field.height * blend;
    return (zoom, y);
  }
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

/// 보스전 카메라(사용자 '보스전이 박진감 넘치게' + '배·보스가 가끔 너무 줌인돼 화면에 잘린다'): 0.6초에 걸쳐 배를 화면 아래
/// [shipAt]로 당기고, 배와 보스가 **잘리지 않는 한** 크게 줌(1.0~fx_map topCam.maxZoom).
/// 잘림 판정 = 보스 그림 반지름 + 위 여백(체력 막대·이름표·흔들림 topPad) · 옆 여백이 **안전 영역**([safeRect] — 위 HUD 띠 아래 끝 ~
/// 선원 줄 위, 좌우 sideDp, fx_map topCam · S4와 같은 값) 안.
/// 보스가 돌진·호를 오가도 잘리지 않게 최근 [_holdMs] 동안 가장 먼 자리 기준, 줌 아웃은 빠르게·줌 인은 천천히 따라간다.
class TopBossCam {
  static const shipAt = 0.72;
  static const _sidePad = 8.0;
  static const _shipR = 34.0; // 배 그림 + 착탄 여유(단위)
  static const _holdMs = 1500.0;

  double blend = 0; // 0 평소 ~ 1 보스전
  double _zoom = 1;
  bool _was = false;
  double _punchAt = -1000000000;
  double _up = 0; // 카메라 점 위로 가장 먼 배·보스 위 끝(단위, 최근 hold)
  double _down = 0; // 카메라 점 아래로 가장 먼 아래 끝
  double _side = 0; // 카메라 점 좌우로 가장 먼 옆 끝
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
    final cfg = scene.fx.raw.obj('topCam');
    final topPad = cfg.number('topPad');
    final maxZoom = cfg.number('maxZoom');
    // 화면 기준점은 카메라 점(topCamera) — 배도 거기서 벗어날 수 있어 배·보스 모두 카메라 점 기준으로 잰다.
    final cam = scene.topCamera;
    final ship = scene.topShip;
    var up = cam.dy - ship.dy + _shipR;
    var down = ship.dy - cam.dy + _shipR;
    var side = (ship.dx - cam.dx).abs() + _shipR;
    for (var k = 0; k < scene.poseCount; k++) {
      final e = scene.poses[k];
      if (!e.boss) continue;
      final r = bossR(e);
      up = math.max(up, cam.dy - e.drawY + r + topPad);
      down = math.max(down, e.drawY - cam.dy + r);
      side = math.max(side, (e.drawX - cam.dx).abs() + r + _sidePad);
    }
    // 최근 가장 먼 자리를 잠깐 붙든다(돌진·호 왕복에도 줌이 들쑥날쑥하지 않게)
    final reset = now - _heldAt > _holdMs || now < _heldAt;
    if (reset || up > _up || down > _down || side > _side) {
      _up = math.max(up, reset ? 0 : _up);
      _down = math.max(down, reset ? 0 : _down);
      _side = math.max(side, reset ? 0 : _side);
      if (reset) _heldAt = now;
    }
    final field = frame.fieldDp;
    final safe = safeRect(scene, frame).deflate(6); // 돌진 출렁임·따라가기 지연 여유
    final d = frame.dot;
    final shipY = field.top + field.height * shipAt;
    // 잘리지 않는 최대 줌: 위(배 ~ 안전 위 끝), 아래(배 ~ 안전 아래 끝), 옆(가운데 ~ 안전 옆 끝)
    var fit = maxZoom;
    if (_up > 0) fit = math.min(fit, (shipY - safe.top) / (_up * d));
    if (_down > 0) fit = math.min(fit, (safe.bottom - shipY) / (_down * d));
    // 옆: 화면 가운데(카메라 점) ~ 가까운 안전 옆 끝(오른쪽은 광고 탭만큼 더 좁다)
    final half = math.min(field.center.dx - safe.left, safe.right - field.center.dx);
    if (_side > 0) fit = math.min(fit, half / (_side * d));
    final want = fit.clamp(0.6, maxZoom);
    if (dt > 0) _zoom += (want - _zoom) * math.min(1, dt / (want < _zoom ? 60 : 500));
    final punchT = (now - _punchAt) / 300;
    final punch = punchT >= 0 && punchT < 1 ? 0.04 * (1 - punchT) * (1 - punchT) : 0.0;
    final zoom = 1 + (_zoom - 1) * blend + punch;
    final y = frame.shipScreen.dy + (shipAt - TopFrame.kShipAt) * field.height * blend;
    return (zoom, y);
  }

  /// 보스전 안전 영역(dp, 전장 상자 기준): 위 = UI가 잰 HUD 띠 아래 끝(BattleGame.hudTopDp) 또는 fx_map topCam.hudTopDp.
  static Rect safeRect(BattleScene scene, TopFrame frame) {
    final cfg = scene.fx.raw.obj('topCam');
    final f = frame.fieldDp;
    final side = cfg.number('sideDp');
    return Rect.fromLTRB(
      f.left + side,
      math.max(f.top, scene.hudTopDp ?? cfg.number('hudTopDp')),
      f.right - cfg.number('rightDp'),
      f.bottom - cfg.number('bottomDp'),
    );
  }
}

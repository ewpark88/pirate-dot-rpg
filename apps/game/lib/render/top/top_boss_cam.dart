import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

/// 보스전 카메라(사용자 '보스전이 박진감 넘치게' + '줌인·아웃하며 움직이는 게 역동적이다, 잘리지만 않게'):
/// 1. 원하는 줌(역동 연출): 배 ↔ 보스 거리가 전장 높이 [fitShare] 안에 꽉 차게 1.0~[maxZoom] — 보스가 다가오면 확 줌인, 물러나면 줌아웃.
///    + 펀치 줌: 등장·보스 사격(HdMuzzle.bossShotAt)·브레이크(TopBreak.brokenAt).
/// 2. 상한 제약만: 그 줌에서 배·보스(체력 막대·이름표 topPad 포함)가 **안전 영역**([safeRect] — 위 HUD 띠 아래 ~ 선원 줄 위,
///    좌우 여백, fx_map topCam · S4와 같은 값)을 벗어나면 그 프레임은 벗어나지 않는 최대 줌으로 깎는다(빠르게 따라감).
class TopBossCam {
  static const fitShare = 0.58;
  static const maxZoom = 1.6;
  static const _sidePad = 8.0;
  static const _shipR = 34.0; // 배 그림 + 착탄 여유(단위)

  double blend = 0; // 0 평소 ~ 1 보스전
  double _zoom = 1;
  double _cap = maxZoom;
  double _y = 0; // 보스전 배 화면 y(dp)
  double _mx = 0; // 보스전 가로 가운데(카메라 점 기준 단위)
  bool _was = false;
  double _punchAt = -1000000000;

  /// 지금 줌(시험 — 역동성 회귀).
  double zoom = 1;

  /// 이번 프레임 (줌, 배 화면 y 목표, 화면 가로 기준점 옮김 dp). [bossR] = 보스 그림 반지름(단위, TopEnemies.radiusOf).
  (double, double, double) update(
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
    final topPad = scene.fx.raw.obj('topCam').number('topPad');
    // 화면 기준점은 카메라 점(topCamera) — 잘림 판정은 배·보스 모두 카메라 점 기준.
    final cam = scene.topCamera;
    final ship = scene.topShip;
    var span = 0.0;
    var up = cam.dy - ship.dy + _shipR;
    var down = ship.dy - cam.dy + _shipR;
    var left = ship.dx - cam.dx - _shipR; // 카메라 점 기준 배·보스 가로 끝
    var right = ship.dx - cam.dx + _shipR;
    for (var k = 0; k < scene.poseCount; k++) {
      final e = scene.poses[k];
      if (!e.boss) continue;
      final r = bossR(e);
      span = math.max(span, (ship.dy - e.drawY).abs() + r + 30);
      up = math.max(up, cam.dy - e.drawY + r + topPad);
      down = math.max(down, e.drawY - cam.dy + r);
      left = math.min(left, e.drawX - cam.dx - r - _sidePad);
      right = math.max(right, e.drawX - cam.dx + r + _sidePad);
    }
    final field = frame.fieldDp;
    final d = frame.dot;
    // 1. 원하는 줌(역동)
    final want = span <= 0 ? 1.0 : (fitShare * field.height / (span * d)).clamp(1.0, maxZoom);
    if (dt > 0) _zoom += (want - _zoom) * math.min(1, dt / 400);
    double pulse(double at, double ms) {
      final t = (now - at) / ms;
      return t >= 0 && t < 1 ? math.sin(t * math.pi) : 0;
    }

    final entry = (now - _punchAt) / 300;
    final punch =
        (entry >= 0 && entry < 1 ? 0.06 * (1 - entry) * (1 - entry) : 0.0) +
        0.05 * pulse(scene.topHits.muzzle.bossShotAt, 260) +
        0.12 * pulse(scene.topHits.breaks.brokenAt, 350);
    // 2. 상한: 안전 영역을 벗어나지 않는 최대 줌(줄일 땐 빠르게, 풀릴 땐 천천히)
    // 배 화면 높이도 움직인다: 배·보스 쌍이 안전 영역 세로 가운데에 오게(배 50~86%) — 줌할 여유가 생기고 카메라가 산다.
    final safe = safeRect(scene, frame).deflate(6); // 돌진 출렁임·따라가기 지연 여유
    // 가로도 배·보스 쌍의 가운데를 안전 영역 가운데로(S1 z02 '배·보스가 멀어 둘 다 작다') — 한쪽으로 몰려 줌을 못 쓰던 것.
    if (dt > 0) _mx += ((left + right) / 2 - _mx) * math.min(1, dt / 350);
    final side = math.max(right - _mx, _mx - left);
    final half = safe.width / 2;
    final zv = safe.height / ((up + down) * d);
    final centred = safe.center.dy + (up - down) / 2 * d * zv;
    final wantY = centred.clamp(field.top + field.height * 0.5, field.top + field.height * 0.86);
    if (dt > 0) _y += (wantY - _y) * math.min(1, dt / 350);
    if (_y == 0) _y = wantY;
    var fit = maxZoom + 0.2;
    fit = math.min(fit, (_y - safe.top) / (up * d));
    fit = math.min(fit, (safe.bottom - _y) / (down * d));
    fit = math.min(fit, half / (side * d));
    if (dt > 0) _cap += (fit - _cap) * math.min(1, dt / (fit < _cap ? 40 : 300));
    final cap = math.min(_cap, fit + 0.02);
    // 보스전 줌 = 역동 줌 + 펀치, 상한(cap)으로 깎은 뒤 평소 ↔ 보스전 사이를 blend로 부드럽게(시작 때 툭 튀지 않게).
    final target = math.min(_zoom + punch, math.max(cap, 0.45)); // 작은 폰·큰 띠에서도 잘리지 않게 0.45까지
    // 처치 피니시 줌 펀치(보스가 사라져 blend가 풀려도 따로 — 0.5초 +0.14, 배만 남아 안전 영역 걱정 없음)
    final fin = (now - scene.moments.finishAt) / 500;
    zoom = 1 + (target - 1) * blend + (fin >= 0 && fin < 1 ? 0.14 * math.sin(fin * math.pi) : 0);
    final y = frame.shipScreen.dy + (_y - frame.shipScreen.dy) * blend;
    final x = ((safe.center.dx - field.center.dx) - _mx * d * zoom) * blend; // 화면 가로 기준점 옮김(dp)
    return (zoom, y, x);
  }

  /// 보스전 안전 영역(dp, 전장 상자 기준): 위 = UI가 잰 HUD 띠 아래 끝(BattleGame.hudTopDp) 또는 fx_map topCam.hudTopDp.
  static Rect safeRect(BattleScene scene, TopFrame frame) {
    final cfg = scene.fx.raw.obj('topCam');
    final f = frame.fieldDp;
    return Rect.fromLTRB(
      f.left + cfg.number('sideDp'),
      math.max(f.top, scene.hudTopDp ?? cfg.number('hudTopDp')),
      f.right - cfg.number('rightDp'),
      f.bottom - cfg.number('bottomDp'),
    );
  }
}

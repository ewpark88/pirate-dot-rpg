import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_boss_cam.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import 'helpers.dart';
import 'top_recording.dart';

/// 회귀(사용자 최우선 '보스전에 배·보스가 한 번씩 너무 줌인돼 화면에 잘린다'): 대보스(1.8배 리바이어던·크라켄·포세이돈)·지역 보스(1.4배 빙산 바다코끼리) 장면을 4기기로
/// 여러 프레임 돌려, 보스전 카메라가 켜진 동안 배·보스(체력 막대 포함) 상자가 안전 영역(TopBossCam.safeRect — S4 위 띠 아래) 안에 늘 들어온다.
void main() {
  const devices = {
    '360': (ui.Size(360, 640 - 148), 3.0),
    's24': (ui.Size(384, 832 - 148), 2.8125),
    '411': (ui.Size(411, 891 - 148), 2.625),
    'tablet': (ui.Size(800, 1280 - 148), 2.0),
    's24_hud120': (ui.Size(384, 832 - 148), 2.8125), // UI가 잰 위 띠가 높을 때(상태 표시줄 + 안내 줄)
    'tablet_hud123': (ui.Size(800, 1280 - 148), 2.0), // 태블릿 띠 82dp × uiScale + 여유(S4)
  };
  for (final MapEntry(key: name, value: (box, dpr)) in devices.entries) {
    for (final stage in const [150, 180, 220, 260]) {
      testWidgets('보스전 줌 잘림 없음 $name 스테이지 $stage', (tester) async {
        final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
        final rec = topRecording(tables, ticks: 400, stage: stage, bossAt: 5);
        final scene = BattleScene(tables, rec, loop: false)
          ..layout = battleFrameFor(box, dpr)
          ..hudTopDp = name.endsWith('hud120') ? 120 : (name.endsWith('hud123') ? 123 : null);
        final painter = ScenePainter(scene)..sprites = bank;
        final frame = topFrameFor(box, dpr);
        final canvas = ui.Canvas(ui.PictureRecorder());
        var checked = 0;
        var worst = 0.0;
        var zMin = 9.0;
        var zMax = 0.0;
        while (scene.player.position < 390) {
          scene.update(kFrameMs);
          painter.paintTop(canvas, frame);
          if (scene.frame.bossActive) {
            zMin = math.min(zMin, painter.top.camZoom); // 등장 줌인부터 보스전 내내
            zMax = math.max(zMax, painter.top.camZoom);
          }
          if (!scene.frame.bossActive || scene.player.position < 40) continue; // 카메라가 다 당겨진 뒤(2초)
          final field = TopBossCam.safeRect(scene, frame).inflate(2); // 안전 영역(위 HUD 띠 아래 ~ 선원 줄 위, 좌우 12dp)
          ui.Rect toScreen(ui.Offset c, double r) => ui.Rect.fromPoints(
            painter.top.worldToScreen(c - ui.Offset(r, r)),
            painter.top.worldToScreen(c + ui.Offset(r, r)),
          );
          final boxes = [toScreen(scene.topShip, 28)];
          for (var k = 0; k < scene.poseCount; k++) {
            final e = scene.poses[k];
            if (!e.boss) continue;
            final r = painter.top.radiusOf(e); // 그린 그림 경계(HD 칸)
            final b = toScreen(ui.Offset(e.drawX, e.drawY), r);
            boxes.add(ui.Rect.fromLTRB(b.left, b.top - 14, b.right, b.bottom)); // 체력 막대·이름표(그림 위 14dp)
          }
          for (final b in boxes) {
            final out = math.max(
              math.max(field.left - b.left, b.right - field.right),
              math.max(field.top - b.top, b.bottom - field.bottom),
            );
            if (out > worst) worst = out;
          }
          checked++;
        }
        expect(checked, greaterThan(20), reason: '보스전 프레임을 충분히 봤다');
        expect(worst, lessThanOrEqualTo(0), reason: '배·보스 상자가 화면 밖으로 ${worst.toStringAsFixed(1)}dp 나감');
        // 역동성 회귀(사용자 '줌인·아웃하며 움직이던 게 좋았다'): 보스전 동안 줌이 0.3 이상 오간다.
        expect(
          zMax - zMin,
          greaterThanOrEqualTo(0.3),
          reason: '줌 ${zMin.toStringAsFixed(2)}~${zMax.toStringAsFixed(2)}',
        );
      });
    }
  }
}

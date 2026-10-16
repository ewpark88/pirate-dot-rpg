import 'dart:ui';

import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

/// 방치 3분 절전 화면 (사용자 '발열', OLED 잔상 걱정, S1): 전장 전체를 아주 어둡게(밝기 frameCap.dimBrightness) +
/// 배·적만 어두운 점으로. 바다·이펙트·숫자·HUD는 그리지 않는다(그리기 수 몇십 개). UI 덮개(문구·깨우기)는 S4.
class TopDim {
  TopDim(this.scene);

  final BattleScene scene;
  final _fill = Paint()..isAntiAlias = false;
  final _dots = <Offset>[];
  final _bossDots = <Offset>[];

  /// [toScreen] = 전장 → 상자 dp(마지막 카메라 그대로 — 방치 중엔 배가 가운데에 거의 머문다).
  void paint(Canvas c, TopFrame frame, Offset Function(Offset world) toScreen, double brightness) {
    final box = Offset.zero & frame.box;
    final b = brightness.clamp(0.0, 1.0);
    _fill.color = Color.fromARGB(255, (0x0B * 4 * b).round(), (0x2A * 4 * b).round(), (0x44 * 4 * b).round());
    c.drawRect(box, _fill);
    _dots.clear();
    _bossDots.clear();
    for (var k = 0; k < scene.poseCount; k++) {
      final p = scene.poses[k];
      (p.boss ? _bossDots : _dots).add(toScreen(Offset(p.drawX, p.drawY)));
    }
    _fill
      ..color = Color.fromARGB(255, (0x8A * b * 2.5).round(), (0x5A * b * 2.5).round(), (0x5A * b * 2.5).round())
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    c.drawPoints(PointMode.points, _dots, _fill);
    _fill.strokeWidth = 8;
    c.drawPoints(PointMode.points, _bossDots, _fill);
    // 배: 조금 더 밝은 세로 점.
    final ship = toScreen(scene.topShip);
    _fill.color = Color.fromARGB(255, (0xC8 * b * 2.5).round(), (0xA0 * b * 2.5).round(), (0x6E * b * 2.5).round());
    c.drawRect(Rect.fromCenter(center: ship, width: 6, height: 12), _fill);
  }
}

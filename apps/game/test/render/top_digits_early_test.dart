import 'dart:ui' show PictureRecorder;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart' show BigNum;
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';
import 'package:pirate_dot/render/scene/top_view.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/text/outline_digits.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import 'helpers.dart';
import 'top_recording.dart';

/// 회귀(S5 실기기 81ace50a — '피해 숫자가 세로로 한 글자씩 쌓인다'): 초반(한 자리 피해)에 테두리 숫자 아틀라스로 그리면
/// 숫자들이 도트 글자 줄 간격으로 쌓여 큰 글자끼리 겹쳤고, 배 피해 '0'(1 미만)이 따로따로 쌓였다.
/// 실기기 dpr 3종(2.625·2.8125·3)으로: 화면 숫자끼리 그린 크기로 겹치지 않고, 배 위 '0'이 없다.
void main() {
  for (final (name, dpr) in const [('411', 2.625), ('s24', 2.8125), ('360', 3.0)]) {
    testWidgets('초반 테두리 숫자 dpr $dpr — 세로로 겹쳐 쌓이지 않음', (tester) async {
      final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
      final digits = (await tester.runAsync(() => OutlineDigits.load(devicePixelRatio: dpr)))!;
      const box = Size(384, 832 - 48 - 24 - 76);
      final rec = topRecording(tables, ticks: 200, stage: 3);
      final scene = BattleScene(tables, rec, loop: false)..layout = battleFrameFor(box, dpr);
      final painter = ScenePainter(scene)
        ..sprites = bank
        ..digits = digits;
      final frame = topFrameFor(box, dpr);
      final warm = Canvas(PictureRecorder());
      var worst = 0;
      while (scene.player.position < 180) {
        scene.update(kFrameMs);
        painter.paintTop(warm, frame);
        final ns = scene.numbers.active.where((n) => n.ageMs > 120).toList(); // 막 생긴 것은 아직 튀어 오르는 중
        for (var i = 0; i < ns.length; i++) {
          for (var j = i + 1; j < ns.length; j++) {
            if (_overlap(scene.numbers, digits, ns[i], ns[j]) > 0.5) worst++;
          }
        }
        expect(scene.numbers.active.where((n) => n.kind == DamageKind.ship && n.text == '0'), isEmpty);
      }
      // 같은 자리에 한 자리 피해 5개(초반 무리) — 위로 비켜 쌓인 줄이 그린 글자 크기만큼 떨어져야 한다.
      final at = scene.topShip - const Offset(0, 40);
      for (var k = 1; k <= 5; k++) {
        scene.numbers.add(BigNum.from(k), at.dx, at.dy, DamageKind.normal, key: 900 + k);
      }
      final fresh = [
        for (final n in scene.numbers.active)
          if (n.key > 900) n,
      ];
      expect(fresh.length, greaterThanOrEqualTo(2)); // 넘치면 위 줄과 합쳐진다
      // 위아래로 쌓인 두 숫자 사이 = 실제 그린 글자 높이(5 × 2.3 × 화면 배율 layout.dot/frame.dot)의 85% 이상.
      final drawn = 5 * 2.3 * scene.layout.dot / frame.dot;
      final ys = [for (final n in fresh) n.y - scene.numbers.riseOf(n)]..sort();
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i] - ys[i - 1], greaterThanOrEqualTo(drawn * 0.85), reason: '쌓인 줄끼리 글자가 겹침(dpr $dpr)');
      }
      expect(worst, lessThan(10), reason: '숫자끼리 절반 넘게 겹친 프레임·쌍 수');
      final pw = (box.width * dpr).roundToDouble();
      final ph = (box.height * dpr).roundToDouble();
      tester.view
        ..physicalSize = Size(pw, ph)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: pw,
              height: ph,
              child: CustomPaint(painter: _Painter(painter, frame, dpr)),
            ),
          ),
        ),
      );
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_digits_early_$name.png'));
    });
  }
}

/// 두 숫자를 실제 그린 크기(HudPainter._outlined와 같은 높이·아틀라스 폭)로 잰 상자가 작은 쪽 넓이의 몇 할만큼 겹치나.
double _overlap(DamageNumbers layer, OutlineDigits d, DamageNumber a, DamageNumber b) {
  Rect box(DamageNumber n) {
    final h = 5 * layer.scaleOf(n) * (n.kind == DamageKind.crit ? 3.0 : 2.3);
    return Rect.fromCenter(
      center: Offset(n.x, n.y - layer.riseOf(n)),
      width: d.layout.measure(n.text, height: h),
      height: h * 0.8,
    );
  }

  final ra = box(a);
  final rb = box(b);
  final i = ra.intersect(rb);
  if (i.width <= 0 || i.height <= 0) return 0;
  final small = ra.width * ra.height < rb.width * rb.height ? ra : rb;
  return i.width * i.height / (small.width * small.height);
}

class _Painter extends CustomPainter {
  _Painter(this.painter, this.frame, this.dpr);
  final ScenePainter painter;
  final TopFrame frame;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(dpr);
    painter.paintTop(canvas, frame);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_v2.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

/// HD v2 보스 시안(사용자 '보스 퀄리티 한 단계 더'): 대보스 바다 악어 — 위 줄 평소 0·0.2·0.4·0.6초, 아래 줄 공격 예고·쓰러짐·
/// 게임 안 크기(약 1/3)·어두운 바다. 그림자 2단(바깥 옅은 것은 굽기 자리).
void main() {
  testWidgets('HD v2 대보스 시안(바다 악어)', (tester) async {
    const size = Size(1200, 640);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const Center(
        child: RepaintBoundary(
          child: SizedBox(width: 1200, height: 640, child: CustomPaint(painter: _Sheet())),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_boss_v2.png'));
  });
}

class _Sheet extends CustomPainter {
  const _Sheet();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2F8FD0))
      ..drawRect(const Rect.fromLTWH(900, 320, 300, 320), Paint()..color = const Color(0xFF16304E));
    final k = HdKit();
    final sp = hdBosses['sea_croc']!;
    void one(double x, double y, double r, double t, HdMood mood) {
      canvas
        ..save()
        ..translate(x, y);
      k
        ..mood = mood
        ..begin(r)
        ..shadow2(canvas, r, sp.ground);
      sp.draw(k, canvas, r, t);
      canvas.restore();
    }

    for (var i = 0; i < 4; i++) {
      one(150 + i * 300.0, 165, 95, i * 200.0, HdMood.idle);
    }
    one(150, 485, 95, 300, HdMood.windup);
    one(450, 485, 95, 300, HdMood.down);
    one(750, 485, 34, 300, HdMood.idle);
    one(1050, 485, 95, 500, HdMood.windup);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_v2.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

/// HD v2 보스(사용자 '보스 퀄리티 한 단계 더'): 표정 보스(hdMoodSpecies)마다 한 줄 — 평소·공격 예고·쓰러짐·게임 안 크기(약 1/3).
void main() {
  testWidgets('HD v2 대보스 시안(바다 악어)', (tester) async {
    final size = Size(1200, 320.0 * hdMoodSpecies.length);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: const CustomPaint(painter: _Sheet()),
          ),
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
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2F8FD0));
    final k = HdKit();
    for (final (row, kind) in hdMoodSpecies.indexed) {
      final sp = hdBosses[kind]!;
      void one(double x, double r, double t, HdMood mood) {
        canvas
          ..save()
          ..translate(x, 160 + row * 320.0);
        k
          ..mood = mood
          ..begin(r)
          ..shadow2(canvas, r, sp.ground);
        sp.draw(k, canvas, r, t);
        canvas.restore();
      }

      one(150, 95, 200, HdMood.idle);
      one(450, 95, 300, HdMood.windup);
      one(750, 95, 300, HdMood.down);
      one(1050, 34, 200, HdMood.idle);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

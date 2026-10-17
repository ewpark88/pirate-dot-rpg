import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

/// HD 카툰 시범 움직임 증거(사용자 승인 시 보여 줄 것): 4종 × 0.1초 간격 8장 — 숨쉬기·집게 까딱·촉수 꿈틀·꼬리 흔들기.
void main() {
  testWidgets('HD 카툰 애니메이션 띠(0.1초 × 8)', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 840)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const Center(
        child: RepaintBoundary(
          child: SizedBox(width: 1600, height: 840, child: CustomPaint(painter: _Strip())),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_trial_anim.png'));
  });
}

class _Strip extends CustomPainter {
  const _Strip();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E3550));
    final k = HdKit();
    for (final (row, kind) in _kinds.indexed) {
      for (var f = 0; f < 8; f++) {
        canvas
          ..save()
          ..translate(100 + f * 200.0, 105 + row * 210.0);
        _paintHd(k, canvas, kind, kind == 'kraken' ? 62 : 46, f * 100.0);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _kinds = ['crab', 'jelly', 'piranha', 'kraken'];

/// 종 하나(그림자 포함) — 굽기(HdSheets.bake)와 같은 순서.
void _paintHd(HdKit k, Canvas c, String kind, double r, double t) {
  final sp = hdEnemies[kind] ?? hdBosses[kind]!;
  k
    ..begin(r)
    ..shadow(c, r, sp.ground);
  sp.draw(k, c, r, t);
}

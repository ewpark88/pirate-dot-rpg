import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/top/top_ship_damage.dart';

/// 배 피격·위기(S1) 시안: 맞음 0.15초 · 체력 40%(연기) · 20%(연기 둘 + 불꽃) · 회복 0.3초. 배는 갈색 둥근 사각으로 대신.
class _Sheet extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1C8FB0));
    final cases = <(double, double, double)>[(1, 0.9, 150), (0.4, 0.4, 500), (0.2, 0.2, 500), (0.5, 0.7, 300)];
    for (var i = 0; i < cases.length; i++) {
      final (from, to, after) = cases[i];
      final ship = Offset(50 + i * 90.0, 110);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: ship, width: 26, height: 44), const Radius.circular(10)),
        Paint()..color = const Color(0xFF9A6A3A),
      );
      TopShipDamage()
        ..paint(canvas, ship, 13, from, 1000, lite: true)
        ..paint(Canvas(PictureRecorder()), ship, 13, to, 1000 + 16, lite: false)
        ..paint(canvas, ship, 13, to, 1000 + after, lite: false);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  test('체력 25% 아래에서만 가장자리 붉은 맥박', () {
    expect(TopShipDamage.edge(0.5, 0), 0);
    expect(TopShipDamage.edge(0, 0), 0, reason: '침몰(0)은 침몰 연출만');
    expect(TopShipDamage.edge(0.2, 0), greaterThan(0));
  });

  testWidgets('배 피격·위기 시안', (tester) async {
    const size = Size(370, 200);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(painter: _Sheet()),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_ship_damage.png'));
  });
}

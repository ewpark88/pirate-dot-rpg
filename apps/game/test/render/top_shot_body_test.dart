import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/top/top_shot_body.dart';

/// 선원 발사체 몸통 HD v2(S1) 시안: 계열 11 × 등급 5(일반 → 신화), 마지막 줄은 집속 갈라짐·붐빔(lite).
const _families = [
  'lob',
  'cluster',
  'ring',
  'direct',
  'pierce',
  'laser',
  'skip',
  'underwater',
  'air',
  'assault',
  'shock',
];

class _Sheet extends CustomPainter {
  final body = TopShotBody();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1C8FB0));
    for (var f = 0; f < _families.length; f++) {
      for (var r = 0; r < 5; r++) {
        body.paint(
          canvas,
          _families[f],
          Offset(40 + r * 64.0, 36 + f * 56.0),
          9 * TopShotBody.scaleOf(r),
          -0.5,
          0.6,
          0.4,
          120,
          r,
          lite: false,
        );
      }
    }
    for (var i = 0; i < 4; i++) {
      body.paint(
        canvas,
        'cluster',
        Offset(40 + i * 64.0, 36 + 11 * 56.0),
        11,
        -1.57,
        0.4,
        0.7 + i * 0.1,
        0,
        2,
        lite: false,
      );
    }
    body.paint(canvas, 'lob', const Offset(40 + 4 * 64.0, 36 + 11 * 56.0), 11, 0, 0.4, 0.4, 0, 4, lite: true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  test('계열 11 모두 몸통이 있다, 등급이 높을수록 크다', () {
    for (final f in _families) {
      expect(TopShotBody.has(f), isTrue, reason: f);
    }
    expect(TopShotBody.scaleOf(4), greaterThan(TopShotBody.scaleOf(0)));
  });

  testWidgets('발사체 몸통 시안(계열 × 등급)', (tester) async {
    const size = Size(340, 700);
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/top_shot_body.png'));
  });
}

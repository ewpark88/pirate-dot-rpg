import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_ship.dart';

/// HD 플레이어 배(개편 ④): 줄 = 등급(dinghy·sloop·warship·ghost), 칸 = 부위 단계 1·2·3·4·5·7 + 오른쪽 끝 축제 무지개 돛.
void main() {
  testWidgets('HD 플레이어 배 단계 한 장', (tester) async {
    const size = Size(1400, 1000);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const Center(
        child: RepaintBoundary(
          child: SizedBox(width: 1400, height: 1000, child: CustomPaint(painter: _Sheet())),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_ship.png'));
  });
}

class _Sheet extends CustomPainter {
  const _Sheet();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2F8FD0));
    final ship = HdShip();
    const tiers = [
      ('dinghy', Size(54, 98)),
      ('sloop', Size(58, 106)),
      ('warship', Size(62, 115)),
      ('ghost', Size(62, 115)),
    ];
    const stages = [1, 2, 3, 4, 5, 7];
    for (final (row, (tier, frame)) in tiers.indexed) {
      for (var i = 0; i <= stages.length; i++) {
        final n = i < stages.length ? stages[i] : 7;
        canvas
          ..save()
          ..translate(100 + i * 200.0, 125 + row * 250.0)
          ..scale(2);
        ship.paint(
          canvas,
          frame,
          {
            for (final p in const ['hull', 'cargo', 'cannon', 'sail', 'crowsnest']) p: n,
          },
          HdShip.tierColors(tier),
          rainbow: i == stages.length,
          tier: tier,
          now: 300,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

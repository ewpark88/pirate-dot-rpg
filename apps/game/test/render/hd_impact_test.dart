import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_impact.dart';

import 'helpers.dart';

/// 계열별 HD 착탄 비교(사용자 '같은 게 많아 보여'): 줄 = 계열 11, 칸 = 등급 0~5(크기·색) × 두 순간(0.12초·0.25초).
void main() {
  testWidgets('계열 × 등급 착탄 한 장', (tester) async {
    const fam = HdImpact.families;
    const cell = 90.0;
    final size = Size(cell * 12, cell * fam.length);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: const CustomPaint(painter: _Sheet(cell)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_impact.png'));
  });
}

class _Sheet extends CustomPainter {
  const _Sheet(this.cell);
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2F8FD0));
    final rs = tables.rarities.rarities;
    for (final (row, f) in HdImpact.families.indexed) {
      for (var rar = 0; rar < 6; rar++) {
        for (final (k, ms) in const [120.0, 250.0].indexed) {
          final hd = HdImpact();
          final col = int.parse('FF${rs[rar.clamp(0, rs.length - 1)].color.substring(1)}', radix: 16);
          final x = (rar * 2 + k + 0.5) * cell;
          final y = (row + 0.5) * cell;
          hd
            ..add(f, x, y, 30, col, rar, 0)
            ..paint(canvas, ms, lite: false);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

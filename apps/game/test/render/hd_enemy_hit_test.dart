import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_sheets.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

/// 잡몹 v2(S1): 잡몹 시트 2·3행 = 맞을 때 찡긋(> < 눈 + 납작) — 종마다 평소 | 찡긋 한 쌍, 27종 한 장.
void main() {
  testWidgets('잡몹 v2 맞음 찡긋 한 장', (tester) async {
    const cell = 120.0;
    const cols = 6;
    final kinds = hdEnemies.keys.toList();
    final sheets = {for (final k in kinds) k: HdSheets.bake(hdEnemies[k]!, cell / 3, 3, hits: true)};
    expect(sheets.values.every((s) => s.hits && s.image.height == s.cell * 4), isTrue);
    final rows = (kinds.length / cols).ceil();
    final size = Size(cell * 2 * cols, cell * rows);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(painter: _Sheet(kinds, sheets, cell, cols)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_enemy_hit.png'));
  });
}

class _Sheet extends CustomPainter {
  _Sheet(this.kinds, this.sheets, this.cell, this.cols);
  final List<String> kinds;
  final Map<String, HdSheet> sheets;
  final double cell;
  final int cols;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2E86C8));
    final p = Paint()..filterQuality = FilterQuality.medium;
    for (final (i, k) in kinds.indexed) {
      final s = sheets[k]!;
      final o = Offset((i % cols) * cell * 2, (i ~/ cols) * cell);
      for (final (j, mood) in const [HdMood.idle, HdMood.hit].indexed) {
        canvas.drawImageRect(
          s.image,
          s.src(2, right: false, mood: mood),
          (o + Offset(j * cell, 0)) & Size(cell, cell),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

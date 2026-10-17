import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_sheets.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

/// HD v2 표정(모든 보스): 게임과 같은 굽기(HdSheets.bake moods)로 — 칸마다 평소·공격 예고·쓰러짐.
/// 대보스 6은 표정을 직접 그리고, 나머지는 공용(HdKit.eye 소용돌이·붉은 눈 + 굽기가 기우뚱·별).
void main() {
  testWidgets('HD 보스 표정 3종 한 장(굽기 그대로)', (tester) async {
    final kinds = [for (final k in hdBosses.keys) k];
    const cell = 150.0;
    const per = 3;
    const cols = 4; // 보스 4마리씩 한 줄
    final rows = (kinds.length / cols).ceil();
    final size = Size(cell * per * cols, cell * rows);
    final sheets = <String, HdSheet>{
      for (final k in kinds)
        k: HdSheets.bake(hdBosses[k]!, cell / 3, 3, moods: true, selfMood: hdMoodSpecies.contains(k)),
    };
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(painter: _Sheet(kinds, sheets, cell)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_boss_moods.png'));
    for (final s in sheets.values) {
      s.image.dispose();
    }
  });
}

class _Sheet extends CustomPainter {
  _Sheet(this.kinds, this.sheets, this.cell);
  final List<String> kinds;
  final Map<String, HdSheet> sheets;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2F8FD0));
    final p = Paint()..filterQuality = FilterQuality.medium;
    for (final (i, k) in kinds.indexed) {
      final s = sheets[k]!;
      for (final (j, mood) in const [HdMood.idle, HdMood.windup, HdMood.down].indexed) {
        final x = ((i % 4) * 3 + j) * cell;
        final y = (i ~/ 4) * cell;
        canvas.drawImageRect(s.image, s.src(4, right: false, mood: mood), Rect.fromLTWH(x, y, cell, cell), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

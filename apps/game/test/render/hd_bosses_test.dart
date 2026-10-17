import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

/// HD 보스 한 장(개편 ④, S3 보스 담당): 줄마다 지금 도트 → HD 0초 → HD 0.4초. hdBosses 전부(크라켄 시범 제외).
void main() {
  testWidgets('HD 보스 비교 한 장', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final kinds = [
      for (final k in hdBosses.keys)
        if (k != 'kraken') k,
    ];
    const cell = 300.0;
    final size = Size(cell * 3, cell * kinds.length);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(painter: _Sheet(bank, kinds, cell)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_bosses.png'));
  });
}

class _Sheet extends CustomPainter {
  _Sheet(this.bank, this.kinds, this.cell);
  final SpriteBank bank;
  final List<String> kinds;
  final double cell;
  final _k = HdKit();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2F7FC4));
    for (final (row, kind) in kinds.indexed) {
      final cy = cell * (row + 0.5);
      final s = bank['td_boss:$kind'];
      if (s != null) {
        final k = cell * 0.9 / s.frameW;
        canvas.drawImageRect(
          s.image,
          Rect.fromLTWH(0, 0, s.frameW, s.frameH),
          Rect.fromCenter(center: Offset(cell / 2, cy), width: s.frameW * k, height: s.frameH * k),
          Paint()..filterQuality = FilterQuality.none,
        );
      }
      final sp = hdBosses[kind]!;
      final r = cell / (2 * sp.extent);
      for (final (i, t) in const [0.0, 400.0].indexed) {
        canvas
          ..save()
          ..translate(cell * (1.5 + i), cy);
        _k
          ..begin(r)
          ..shadow(canvas, r, sp.ground);
        sp.draw(_k, canvas, r, t);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

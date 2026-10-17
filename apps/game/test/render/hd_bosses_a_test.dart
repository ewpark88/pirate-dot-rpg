import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

/// HD 배 보스 무리(S5 — 공용 몸 boss_ship.dart): 칸마다 왼쪽 지금 도트, 가운데 HD 0초, 오른쪽 HD 0.4초.
/// 칸 크기 = fx_map bossLook w(순환 56 · 중간 44 · 기본 해적선 40)에 비례 — 게임 안 크기 차이가 보이게.
const _bosses = [
  ('enemy_ship', 40),
  ('storm_raider', 56),
  ('frost_pirate', 56),
  ('blaze_pirate', 56),
  ('hunter_sub', 56),
  ('wraith_ship', 56),
  ('raider_ship', 44),
  ('storm_pirate', 44),
  ('icebreaker', 44),
  ('fire_pirate', 44),
  ('deep_sub', 44),
  ('ghost_ship', 44),
];

void main() {
  testWidgets('HD 배 보스 무리 비교 한 장', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const w = 1500.0;
    const h = 1040.0;
    tester.view
      ..physicalSize = const Size(w, h)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: w,
            height: h,
            child: CustomPaint(painter: _Sheet(bank)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_bosses_a.png'));
  });
}

class _Sheet extends CustomPainter {
  _Sheet(this.bank);
  final SpriteBank bank;
  final _k = HdKit();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E3550));
    const colW = 500.0;
    const rowH = 260.0;
    for (final (i, (id, units)) in _bosses.indexed) {
      final x0 = (i % 3) * colW;
      final cy = (i ~/ 3) * rowH + rowH / 2;
      final cell = 150.0 * units / 56;
      final s = bank['td_boss:$id'];
      if (s != null) {
        final scale = cell / s.frameW;
        canvas.drawImageRect(
          s.image,
          Rect.fromLTWH(0, 0, s.frameW, s.frameH),
          Rect.fromCenter(center: Offset(x0 + 85, cy), width: s.frameW * scale, height: s.frameH * scale),
          Paint()..filterQuality = FilterQuality.none,
        );
      }
      final sp = hdBosses[id]!;
      final r = cell / (2 * sp.extent);
      for (final (j, t) in const [0.0, 400.0].indexed) {
        canvas
          ..save()
          ..translate(x0 + 245 + j * 160.0, cy);
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

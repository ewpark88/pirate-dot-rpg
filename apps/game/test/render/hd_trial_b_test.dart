import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

/// HD 카툰 B 묶음(S2 — 화산·심연·유령 잡몹, docs/specs/economy-hd-monsters-b.md). S3 hd_trial 골든과 따로(S5 a 묶음과 충돌 없게).
/// 종마다 한 줄: 왼쪽 지금 도트(바다색 칸) · HD(바다색 칸) · HD 움직임 띠 0.1초 × 8(어두운 칸, 그림자 포함 — 굽기와 같은 순서).
void main() {
  testWidgets('HD 카툰 B 묶음 한 장(도트 vs HD + 8장 띠)', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final size = Size(1500, _rowH * _kinds.length);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(painter: _Sheet(bank)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_trial_b.png'));
  });
}

const _kinds = [
  'starfish',
  'starfish_small',
  'lavacrab',
  'lavacrab_small',
  'lavaturtle',
  'firebird',
  'angler',
  'squid',
  'siphon',
  'eel',
];
const _rowH = 150.0;

class _Sheet extends CustomPainter {
  _Sheet(this.bank);
  final SpriteBank bank;

  @override
  void paint(Canvas canvas, Size size) {
    final k = HdKit();
    for (final (row, kind) in _kinds.indexed) {
      final top = row * _rowH;
      final cy = top + _rowH / 2;
      final small = kind.endsWith('_small');
      final r = small ? 30.0 : 42.0;
      canvas
        ..drawRect(Rect.fromLTWH(0, top, 300, _rowH), Paint()..color = const Color(0xFF2F7FC4))
        ..drawRect(Rect.fromLTWH(300, top, size.width - 300, _rowH), Paint()..color = const Color(0xFF1E3550));
      final s = bank['td_enemy:$kind'];
      if (s != null) {
        final scale = (small ? 70 : 96) / s.frameW;
        canvas.drawImageRect(
          s.image,
          Rect.fromLTWH(0, 0, s.frameW, s.frameH),
          Rect.fromCenter(center: Offset(75, cy), width: s.frameW * scale, height: s.frameH * scale),
          Paint()..filterQuality = FilterQuality.none,
        );
      }
      _hd(k, canvas, kind, Offset(225, cy), r, 300);
      for (var f = 0; f < HdKit.frames; f++) {
        _hd(k, canvas, kind, Offset(375 + f * 140.0, cy), r, f * HdKit.loopMs / HdKit.frames);
      }
    }
  }

  void _hd(HdKit k, Canvas c, String kind, Offset at, double r, double t) {
    final sp = hdEnemies[kind]!;
    c
      ..save()
      ..translate(at.dx, at.dy);
    k
      ..begin(r)
      ..shadow(c, r, sp.ground);
    sp.draw(k, c, r, t);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

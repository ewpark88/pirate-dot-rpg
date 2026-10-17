import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

/// HD 몬스터 묶음 A(S5 — 산호·폭풍·빙하, docs/specs/platform-hd-monsters-a.md): 종마다 한 줄 — 왼쪽 지금 도트,
/// 오른쪽 HD 8장 고리(0.1초씩). 줄 바탕 = 그 해역 바다 v2 색(산호 청록 · 폭풍 회청 · 빙하 하늘).
const _kinds = [
  'gull',
  'urchin',
  'flyingfish',
  'stormgull',
  'puffer',
  'icecrab',
  'icecrab_small',
  'penguin',
  'seal',
  'snowgull',
];
const _sea = {
  'gull': Color(0xFF178CA6),
  'urchin': Color(0xFF2B3E52),
  'flyingfish': Color(0xFF2B3E52),
  'stormgull': Color(0xFF2B3E52),
  'puffer': Color(0xFF2B3E52),
  'icecrab': Color(0xFF3F8FC8),
  'icecrab_small': Color(0xFF3F8FC8),
  'penguin': Color(0xFF3F8FC8),
  'seal': Color(0xFF3F8FC8),
  'snowgull': Color(0xFF3F8FC8),
};

void main() {
  testWidgets('HD 묶음 A 비교 한 장', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const w = 1500.0;
    final h = 150.0 * _kinds.length;
    tester.view
      ..physicalSize = Size(w, h)
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_trial_a.png'));
  });
}

class _Sheet extends CustomPainter {
  _Sheet(this.bank);
  final SpriteBank bank;
  final _k = HdKit();

  @override
  void paint(Canvas canvas, Size size) {
    const rowH = 150.0;
    for (final (i, kind) in _kinds.indexed) {
      canvas.drawRect(Rect.fromLTWH(0, i * rowH, size.width, rowH), Paint()..color = _sea[kind]!);
      final cy = i * rowH + rowH / 2;
      final s = bank['td_enemy:$kind'];
      if (s != null) {
        final scale = 96 / s.frameW;
        canvas.drawImageRect(
          s.image,
          Rect.fromLTWH(0, 0, s.frameW, s.frameH),
          Rect.fromCenter(center: Offset(80, cy), width: s.frameW * scale, height: s.frameH * scale),
          Paint()..filterQuality = FilterQuality.none,
        );
      }
      for (var f = 0; f < HdKit.frames; f++) {
        canvas
          ..save()
          ..translate(230 + f * 160, cy);
        // 게임 안처럼 칸(같은 크기)에 맞춘 반지름 — extent가 크면 작게 보인다(작은 얼음게 '반 크기').
        final sp = hdEnemies[kind]!;
        final r = 40 * 1.35 / sp.extent;
        _k
          ..begin(r)
          ..shadow(canvas, r, sp.ground);
        sp.draw(_k, canvas, r, f * HdKit.loopMs / HdKit.frames);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

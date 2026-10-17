import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

/// 디자인 개편 ④ 시범(쿵푸할매 스타일): 몬스터 3(게·해파리·피라냐) + 보스 1(크라켄) — 왼쪽 지금 도트, 오른쪽 HD 카툰.
/// 위 줄 = 지금 바다색, 아래 줄 = 어두운 톤 바다(캐릭터가 튀게). 사용자 승인 전 시범 — 전체 진행 금지.
void main() {
  testWidgets('HD 카툰 시범 비교 한 장', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    const keys = {
      'crab': 'td_enemy:crab',
      'jelly': 'td_enemy:jelly',
      'piranha': 'td_enemy:piranha',
      'kraken': 'td_boss:kraken',
    };
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: 1600,
            height: 900,
            child: CustomPaint(painter: _Sheet(bank, keys)),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_trial.png'));
  });
}

class _Sheet extends CustomPainter {
  _Sheet(this.bank, this.keys);
  final SpriteBank bank;
  final Map<String, String> keys;
  final _k = HdKit();

  @override
  void paint(Canvas canvas, Size size) {
    const bgs = [Color(0xFF2F7FC4), Color(0xFF1E3550)];
    final cell = size.width / 8;
    for (var row = 0; row < 2; row++) {
      canvas.drawRect(Rect.fromLTWH(0, row * size.height / 2, size.width, size.height / 2), Paint()..color = bgs[row]);
      for (final (i, kind) in _kinds.indexed) {
        final boss = kind == 'kraken';
        final cx = cell * (i * 2 + 0.5);
        final cy = row * size.height / 2 + size.height / 4;
        // 지금 도트(가장 가까운 이웃으로 확대)
        final s = bank[keys[kind]!];
        if (s != null) {
          final scale = (boss ? 170 : 110) / s.frameW;
          canvas.drawImageRect(
            s.image,
            Rect.fromLTWH(0, 0, s.frameW, s.frameH),
            Rect.fromCenter(center: Offset(cx, cy), width: s.frameW * scale, height: s.frameH * scale),
            Paint()..filterQuality = FilterQuality.none,
          );
        }
        // HD 카툰
        canvas
          ..save()
          ..translate(cx + cell, cy);
        _paintHd(_k, canvas, kind, boss ? 70 : 46, 400);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _kinds = ['crab', 'jelly', 'piranha', 'kraken'];

/// 종 하나(그림자 포함) — 굽기(HdSheets.bake)와 같은 순서.
void _paintHd(HdKit k, Canvas c, String kind, double r, double t) {
  final sp = hdEnemies[kind] ?? hdBosses[kind]!;
  k
    ..begin(r)
    ..shadow(c, r, sp.ground);
  sp.draw(k, c, r, t);
}

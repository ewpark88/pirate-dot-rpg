import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/preview/crew_preview_view.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import '../render/helpers.dart';
import '../ui/ui_harness.dart';

/// 선원 공격 미리보기 작은 전장(상세 창 폭 × 180dp) — 무리 차례(2초)·보스 차례(7초), 4기기.
const List<(String, double, double)> _devices = [
  ('360', 360, 3.0),
  ('s24', 384, 2.8125),
  ('411', 411, 2.625),
  ('tablet', 800, 2.0),
];

void main() {
  setUpAll(loadGoldenFonts);
  for (final (name, width, dpr) in _devices) {
    for (final sec in const [2, 7]) {
      testWidgets('미리보기 $name ${sec}s', (tester) async {
        tester.view
          ..physicalSize = Size(width * dpr, 260 * dpr)
          ..devicePixelRatio = dpr;
        addTearDown(tester.view.reset);
        final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Center(
              child: SizedBox(
                key: const Key('box'),
                width: width - 64,
                height: (width - 64) * 9 / 16,
                child: CrewPreviewView(tables: tables, crewId: 'pang', level: 30, sprites: bank),
              ),
            ),
          ),
        );
        for (var i = 0; i < sec * 60; i++) {
          await tester.pump(const Duration(microseconds: 16667));
        }
        await expectLater(find.byKey(const Key('box')), matchesGoldenFile('goldens/crew_preview_${name}_$sec.png'));
      });
    }
  }
}

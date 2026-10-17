import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/top/ship_preview.dart';

import 'helpers.dart';

/// 패스·상점 스킨 5종(S2 iap-contract): 색(fx_map skinPreview) + HD 장식(HdPassDecor) — 줄 = 군함·슬루프·유령 등급.
/// 색 바꾸기 + 무늬(무지개 돛·점 무늬). 위 줄 = 군함(warship) 부품 4단계, 아래 줄 = 슬루프(sloop) 3단계.
void main() {
  testWidgets('패스·상점 스킨 5종 × 등급 3', (tester) async {
    const ids = ['pass_s1', 'sprout', 'golden_galleon', 'jolly_flag', 'coral_yacht'];
    final skins = tables.fxMap.raw.obj('topShip').obj('skinPreview');
    Map<String, int> look(int n) => {
      for (final p in ['hull', 'cargo', 'cannon', 'sail', 'crowsnest']) p: n,
    };
    await tester.runAsync(() => ShipPreview.preload(tables, skins: {for (final s in ids) s: skins.obj(s)}));
    tester.view
      ..physicalSize = const Size(1540, 780)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ColoredBox(
          color: const Color(0xFF2A7FCC),
          child: RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (tier, n) in const [('warship', 5), ('sloop', 3), ('ghost', 6)])
                  Row(
                    children: [
                      for (final s in ids)
                        ShipPreview(
                          tables: tables,
                          tier: tier,
                          look: look(n),
                          skin: s,
                          skinPalette: skins.obj(s),
                          size: 110,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/ship_skins_pass.png'));
  });
}

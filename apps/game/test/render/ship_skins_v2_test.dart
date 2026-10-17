import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/top/ship_preview.dart';

import 'helpers.dart';

/// 배 스킨 v2(사용자 #8 '배 스킨을 늘려서 재미'): 새 6종 — 해적왕 금장·유령선·얼음 쇄빙선·용암 철갑선·산호 요정선·무지개 축제선.
/// 색 바꾸기 + 무늬(무지개 돛·점 무늬). 위 줄 = 군함(warship) 부품 4단계, 아래 줄 = 슬루프(sloop) 3단계.
void main() {
  testWidgets('배 스킨 v2 시안: 새 6종 × 등급 2', (tester) async {
    const ids = ['king', 'ghostship', 'frost', 'lava', 'fairy', 'festival', 'abyss'];
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
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/ship_skins_v2.png'));
  });
}

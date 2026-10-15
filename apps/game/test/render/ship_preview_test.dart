import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/top/ship_preview.dart';

import 'helpers.dart';

/// 배 미리보기 위젯(S4 배 탭·축하 팝업·스킨 고르기): 위 줄 = 등급 4개(부품 단계 = 등급 순서대로 1·3·5·7),
/// 아래 줄 = 군함 기본 + 환생 스킨 4종(fx_map topShip.skinPreview). 전장과 같은 층·색 바꾸기.
void main() {
  testWidgets('배 미리보기 골든: 등급 4 + 스킨 4', (tester) async {
    final skins = tables.fxMap.raw.obj('topShip').obj('skinPreview');
    Map<String, int> look(int s) => {
      for (final p in ['hull', 'cargo', 'cannon', 'sail', 'crowsnest']) p: s,
    };
    await tester.runAsync(
      () => ShipPreview.preload(
        tables,
        skins: {
          for (final s in ['coral', 'royal', 'shadow', 'phantom']) s: skins.obj(s),
        },
      ),
    );
    tester.view
      ..physicalSize = const Size(1000, 440)
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
                Row(
                  children: [
                    for (final (i, t) in ['dinghy', 'sloop', 'warship', 'ghost'].indexed)
                      ShipPreview(tables: tables, tier: t, look: look(i * 2 + 1), size: 110),
                  ],
                ),
                Row(
                  children: [
                    ShipPreview(tables: tables, tier: 'warship', look: look(4), size: 100),
                    for (final s in ['coral', 'royal', 'shadow', 'phantom'])
                      ShipPreview(
                        tables: tables,
                        tier: 'warship',
                        look: look(4),
                        skin: s,
                        skinPalette: skins.obj(s),
                        size: 100,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/ship_preview.png'));
  });
}

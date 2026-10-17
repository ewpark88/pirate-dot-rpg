import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/hud/hud_layout.dart';

import 'ui_harness.dart';

// HUD 배치 안 (사용자 2026-10-17 '상태바와 메뉴바 위치를 더 좋은 곳으로 — 가능한지 검토'): 지금 + 대안 3개 × 4기기 시안.
// 고르면 그 하나만 남긴다. 운영자 패널 '렌더 → HUD 배치 안'에서 폰으로도 바꿔 본다.

class _Fixed extends HudLayoutNotifier {
  _Fixed(this.layout);

  final HudLayout layout;

  @override
  HudLayout build() => layout;
}

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('384', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

void main() {
  setUpAll(loadGoldenFonts);

  for (final layout in HudLayout.values) {
    for (final (name, size, dpr) in _devices) {
      testWidgets('배치 ${layout.name} $name — 넘치지 않고 그려진다', (tester) async {
        await pumpGame(
          tester,
          loadFixture('stage37_midgame'),
          openTab: false,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
          overrides: [hudLayoutProvider.overrideWith(() => _Fixed(layout))],
        );
        await precacheImages(tester);
        expect(find.byKey(const Key('hud.gauge')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../goldens/hud_layout_${layout.name}_$name.png'),
        );
      });
    }
  }
}

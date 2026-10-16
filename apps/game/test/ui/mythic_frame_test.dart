import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

import 'ui_harness.dart';

// 사용자 지시 2026-10-16: "신화는 빨간색 테두리로. 희귀랑 색이 비슷해 차이가 안 난다."

void main() {
  test('등급 색 토큰: 신화 = 진한 빨강(희귀 파랑과 다름), 나머지는 표 그대로', () {
    final r = GameTables.load().rarities;
    expect(rarityColor(r.byId('mythic')), mythicRed);
    expect(rarityColor(r.byId('rare')), isNot(mythicRed));
    expect(rarityColor(r.byId('rare')), Color(int.parse('FF${r.byId('rare').color.substring(1)}', radix: 16)));
    expect(rarityInnerGold(r.byId('mythic')), isTrue);
    expect(rarityInnerGold(r.byId('legend')), isFalse);
  });

  testWidgets('도감: 신화 카드에 빨강 + 금 테두리', (tester) async {
    await pumpGame(tester, loadFixture('all_crews_mythic'), tab: crewTab, fullSheet: true);
    expect(find.byKey(const Key('pb.mythicFrame')), findsWidgets);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);

    testWidgets('신화 도감 360', (tester) async {
      await pumpGame(
        tester,
        loadFixture('all_crews_mythic'),
        tab: crewTab,
        size: const Size(360, 640),
        dpr: 3,
        locale: const Locale('ko'),
        fullSheet: true,
      );
      await tester.ensureVisible(find.byKey(const Key('crew.card.octo')));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_mythic_frame_360.png'));
    });
  });
}

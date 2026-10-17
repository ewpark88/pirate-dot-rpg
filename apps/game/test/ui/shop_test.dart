import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/shop/shop_sheet.dart';

import 'ui_harness.dart';

// 유료 상점 골격 (사용자 2026-10-17, 결제 전 가짜 목록): 상품 카드 · 할인 리본 · 인기 · 구독 남은 기간 · 광고 없음 ·
// 스타터 팩 1회 팝업. 4기기 시안.

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('384', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

void main() {
  testWidgets('상점: 상품 6개 · 할인 리본(스타터·보물함) · 구독 12일 · 광고 없음', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), openTab: false);
    showShop(tester.element(find.byType(HomeScreen))).ignore();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop.sheet')), findsOneWidget);
    expect(find.byKey(const Key('shop.off.starter')), findsOneWidget);
    expect(find.byKey(const Key('shop.off.gems_l')), findsOneWidget);
    expect(find.text('Subscribed · 12 days left'), findsOneWidget);
    expect(find.byKey(const Key('shop.noAds')), findsOneWidget);
  });

  for (final (name, size, dpr) in _devices) {
    testWidgets('골든: 상점 · 스타터 팩 ko $name', (tester) async {
      await loadGoldenFonts();
      await pumpGame(
        tester,
        loadFixture('stage37_midgame'),
        openTab: false,
        size: size,
        dpr: dpr,
        locale: const Locale('ko'),
      );
      final ctx = tester.element(find.byType(HomeScreen));
      showShop(ctx).ignore();
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_shop_$name.png'));
      Navigator.of(tester.element(find.byKey(const Key('shop.sheet')))).pop();
      await tester.pumpAndSettle();
      showSkinDialog<void>(ctx, builder: (_) => const StarterPackDialog()).ignore();
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_shop_starter_$name.png'));
    });
  }
}

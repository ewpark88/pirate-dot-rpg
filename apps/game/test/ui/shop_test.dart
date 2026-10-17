import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/purchase/purchase_providers.dart';
import 'package:pirate_dot/adapters/purchase/purchase_types.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/shop/iap_text.dart';
import 'package:pirate_dot/ui/shop/shop_offers.dart';
import 'package:pirate_dot/ui/shop/shop_sheet.dart';

import 'ui_harness.dart';

// 유료 상점 (S5 결제 배선 · S2 iap.json 18종): 가격은 결제 서비스(products().price), 가격 없는 상품은 숨김.
// 묶음 · 첫 구매 ×2 · 보유 중 · 구독 남은 일수 · 월간 젬 오늘 받기 · 구매 → service.buy. 4기기 골든.

class _FakeShop implements PurchaseService {
  _FakeShop({this.hide = const {}});

  final Set<String> hide;
  final bought = <String>[];

  @override
  Future<bool> available() async => true;

  @override
  Future<List<ProductInfo>> products(Set<String> ids) async => [
    for (final id in ids)
      if (!hide.contains(id)) ProductInfo(id: id, kind: ProductKind.consumable, price: '₩${id.length},900'),
  ];

  @override
  Future<void> buy(String productId) async => bought.add(productId);

  @override
  Stream<PurchaseUpdate> get updates => const Stream.empty();

  @override
  Future<void> restore({required Set<String> active}) async {}

  @override
  Future<void> complete(String token) async {}
}

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('384', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

/// 젬 120을 한 번 샀고 · 영구 2배속 보유 · 월간 젬 구독 12일 남음(오늘 아직 안 받음).
GameState _state() {
  final s = loadFixture('stage37_midgame');
  final at = s.savedAt.toUtc();
  return s.copyWith(
    entitlements: {
      'product:gem_120': Entitlement(since: at),
      'product:speed': Entitlement(since: at),
      'speed': Entitlement(since: at),
      'product:gem_monthly': Entitlement(since: at),
      'gemSub': Entitlement(since: at, until: at.add(const Duration(days: 11, hours: 3))),
    },
  );
}

void main() {
  test('표의 상품 이름이 모두 있다(iap.json nameKey → econ ARB)', () {
    for (final p in GameTables.load().iap.products.values) {
      expect(hasIapName(p.nameKey), isTrue, reason: p.nameKey);
    }
  });

  testWidgets('상점: 위 막대 버튼 → 묶음 · 첫 구매 ×2(산 120 빼고) · 보유 중 · 구독 남은 일수 · 구매 → buy', (tester) async {
    final shop = _FakeShop(hide: {'skin_bundle'});
    await pumpGame(
      tester,
      _state(),
      openTab: false,
      size: const Size(400, 3000),
      overrides: [purchaseServiceProvider.overrideWithValue(shop)],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hud.shop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop.sec.gems')), findsOneWidget);
    expect(find.byKey(const Key('shop.double.gem_120')), findsNothing);
    expect(find.byKey(const Key('shop.double.gem_650')), findsOneWidget);
    expect(find.byKey(const Key('shop.owned.speed')), findsOneWidget);
    expect(find.byKey(const Key('shop.left.gem_monthly')), findsOneWidget);
    expect(find.byKey(const Key('shop.product.skin_bundle')), findsNothing); // 가격 없음 → 숨김
    await tester.tap(find.byKey(const Key('shop.buy.gem_650')));
    await tester.pump();
    expect(shop.bought, ['gem_650']);
  });

  testWidgets('결제가 안 되면 상점 버튼이 없다', (tester) async {
    await pumpGame(tester, _state(), openTab: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hud.shop')), findsNothing);
  });

  for (final (name, size, dpr) in _devices) {
    testWidgets('골든: 상점 · 스타터 팩 ko $name', (tester) async {
      await loadGoldenFonts();
      await pumpGame(
        tester,
        _state(),
        openTab: false,
        size: size,
        dpr: dpr,
        locale: const Locale('ko'),
        overrides: [purchaseServiceProvider.overrideWithValue(_FakeShop())],
      );
      await tester.pumpAndSettle();
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

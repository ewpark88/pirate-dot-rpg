import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';

// 유료 상점 골격 (사용자 2026-10-17 '유료 상품 추가'): S2 상품 기획서·S5 결제 어댑터가 오기 전 가짜 목록(임시 어댑터).
// 진짜 결제 전이라 상점은 꺼 둔다([shopEnabledProvider] — 운영자 패널에서만 연다). 가격 글은 결제 스토어가 준다.

enum ProductKind { gems, starter, noAds, sub }

/// 상품 한 칸. discountPct가 있으면 할인 리본, best면 '인기'.
typedef ShopProduct = ({
  String id,
  ProductKind kind,
  String name,
  String icon,
  List<String> contents,
  String price,
  int? discountPct,
  bool best,
});

/// 상점 상태: 광고 없음을 샀는지 · 구독 남은 날.
typedef ShopStatus = ({bool noAds, int? subDaysLeft});

abstract interface class ShopCatalog {
  List<ShopProduct> products(AppLocalizations l);
  ShopStatus status();
}

class FakeShopCatalog implements ShopCatalog {
  const FakeShopCatalog();

  @override
  List<ShopProduct> products(AppLocalizations l) => [
    (
      id: 'starter',
      kind: ProductKind.starter,
      name: l.uiShopStarter,
      icon: UiSprites.chest,
      contents: [l.uiShopGemsN(500), l.uiShopSummonN(10)],
      price: l.uiShopPrice('3,300'),
      discountPct: 70,
      best: false,
    ),
    (
      id: 'gems_s',
      kind: ProductKind.gems,
      name: l.uiShopGemsS,
      icon: UiSprites.gem,
      contents: [l.uiShopGemsN(120)],
      price: l.uiShopPrice('1,200'),
      discountPct: null,
      best: false,
    ),
    (
      id: 'gems_m',
      kind: ProductKind.gems,
      name: l.uiShopGemsM,
      icon: UiSprites.gem,
      contents: [l.uiShopGemsN(700)],
      price: l.uiShopPrice('6,500'),
      discountPct: null,
      best: true,
    ),
    (
      id: 'gems_l',
      kind: ProductKind.gems,
      name: l.uiShopGemsL,
      icon: UiSprites.gem,
      contents: [l.uiShopGemsN(1600)],
      price: l.uiShopPrice('12,000'),
      discountPct: 20,
      best: false,
    ),
    (
      id: 'no_ads',
      kind: ProductKind.noAds,
      name: l.uiShopNoAdsName,
      icon: UiSprites.ad,
      contents: [l.uiShopNoAds],
      price: l.uiShopPrice('5,900'),
      discountPct: null,
      best: false,
    ),
    (
      id: 'sub',
      kind: ProductKind.sub,
      name: l.uiShopSubName,
      icon: UiSprites.trophy,
      contents: [l.uiShopDailyGems(100), l.uiShopNoAds],
      price: l.uiShopPrice('9,900'),
      discountPct: null,
      best: false,
    ),
  ];

  @override
  ShopStatus status() => (noAds: false, subDaysLeft: 12);
}

final shopCatalogProvider = Provider<ShopCatalog>((_) => const FakeShopCatalog());

/// 상점을 열지 — 진짜 결제(S5 어댑터)가 오기 전엔 꺼 둔다. 운영자 패널·시험만 켠다.
final shopEnabledProvider = Provider<bool>((_) => false);

/// 스타터 팩 팝업 본 기록(세이브 hints).
const starterPackHint = 'shop.starter';

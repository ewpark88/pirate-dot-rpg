import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/purchase/purchase_providers.dart';
import 'package:pirate_dot/adapters/purchase/purchase_types.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 유료 상점 (S5 결제 배선 · S2 iap.json 18종, 기획 docs/specs/economy-iap.md): 상품·효과는 표, 가격은 스토어(products().price).
// 가격이 없는 상품은 숨긴다. 결제 서비스가 없으면(iOS·SDK 실패) 상점 버튼째 숨긴다.

/// 스토어가 준 상품 정보(id → 현지화 가격). 결제가 안 되면 빈 맵.
final shopPricesProvider = FutureProvider<Map<String, ProductInfo>>((ref) async {
  final service = ref.watch(purchaseServiceProvider);
  if (!await service.available()) return const {};
  final ids = {for (final p in ref.watch(tablesProvider).iap.products.values) p.id};
  return {for (final p in await service.products(ids)) p.id: p};
});

/// 상점을 열 수 있나(가격을 받은 상품이 하나라도).
final shopOpenProvider = Provider<bool>((ref) => ref.watch(shopPricesProvider).value?.isNotEmpty ?? false);

/// 상점 묶음 — 화면 순서.
enum ShopSection { starter, convenience, gems, monthly, pass, skins }

ShopSection shopSectionOf(IapProduct p) => switch (p) {
  IapProduct(id: 'starter_pack') => ShopSection.starter,
  IapProduct(id: 'gem_monthly') => ShopSection.monthly,
  IapProduct(id: 'voyage_pass') => ShopSection.pass,
  IapProduct(kind: 'consumable') => ShopSection.gems,
  IapProduct(skins: [_, ...], entitlements: []) => ShopSection.skins,
  _ => ShopSection.convenience,
};

/// 산 기록(경제 grantPurchase가 `product:<id>`로 남긴다).
Entitlement? boughtRecord(GameState s, String productId) => s.entitlements['product:$productId'];

/// 상품 한 칸의 지금 상태.
typedef ShopOffer = ({
  IapProduct product,
  String price,

  /// 비소모(영구·스킨·스타터)를 이미 샀다 → '보유 중', 버튼 없음.
  bool owned,

  /// 구독 남은 일수(켜져 있을 때만).
  int? daysLeft,

  /// 젬 팩 첫 구매 ×2 리본.
  bool firstDouble,
});

/// 묶음별 상품(가격이 있는 것만, 표 순서).
final shopOffersProvider = Provider<Map<ShopSection, List<ShopOffer>>>((ref) {
  final prices = ref.watch(shopPricesProvider).value ?? const {};
  final t = ref.watch(tablesProvider);
  final s = ref.watch(gameStateProvider.select((s) => (s.entitlements, s.ship.skinsOwned)));
  final state = ref.read(gameStateProvider);
  final now = ref.watch(clockProvider).now();
  final out = <ShopSection, List<ShopOffer>>{};
  for (final p in t.iap.products.values) {
    final price = prices[p.id]?.price;
    if (price == null) continue;
    final bought = boughtRecord(state, p.id);
    final owned = switch (p.kind) {
      'nonConsumable' =>
        bought != null && (p.limit == null || bought.count >= p.limit!) ||
            (p.skins.isNotEmpty && p.skins.every(s.$2.contains) && p.entitlements.isEmpty && p.gems == 0),
      _ => false,
    };
    int? daysLeft;
    if (p.kind == 'subscription' && p.entitlements.isNotEmpty) {
      final until = state.entitlements[p.entitlements.first.id]?.until;
      if (until != null && until.isAfter(now)) daysLeft = until.difference(now).inHours ~/ 24 + 1;
    }
    out.putIfAbsent(shopSectionOf(p), () => []).add((
      product: p,
      price: price,
      owned: owned,
      daysLeft: daysLeft,
      firstDouble: p.firstBuyDouble && bought == null,
    ));
  }
  return out;
});

/// 상품 구성 줄('젬 600' · '영웅 카드 1장' · '광고 없이 보상' · '30일' …).
List<String> offerLines(AppLocalizations l, IapProduct p, GameTables t) => [
  if (p.gems > 0) l.uiShopGemsN(p.gems),
  if (p.summons > 0) l.uiShopSummonN(p.summons),
  if (p.heroCards > 0) l.uiShopHeroCards(p.heroCards),
  if (p.skins.isNotEmpty) l.uiShopSkinN(p.skins.length),
  for (final r in p.entitlements)
    switch (r.id) {
      'noAds' => l.uiShopRightNoAds,
      'speed' => l.uiShopRightSpeed,
      'offline12' => l.uiShopRightOffline(t.iap.offlineHours),
      'gemSub' => l.uiShopDailyGems(t.iap.gemSubDaily),
      'pass' => l.uiShopRightPass,
      _ => r.id,
    },
  if (p.entitlements.isNotEmpty)
    switch (p.entitlements.first.days) {
      final d? => l.uiShopDays(d),
      null => l.uiShopForever,
    },
];

/// 스타터 팩 팝업을 처음 띄운 날(세이브 hints 'shop.starter@yyyy-MM-dd') — 그날부터 [starterDays]일만 판다.
const starterHintPrefix = 'shop.starter@';
const starterDays = 7;

DateTime? starterShownOn(GameState s) {
  for (final h in s.settings.hints) {
    if (h.startsWith(starterHintPrefix)) return DateTime.tryParse(h.substring(starterHintPrefix.length));
  }
  return null;
}

/// 스타터 팩 판매 끝 시각(아직 안 띄웠으면 null = 끝 없음).
DateTime? starterEnds(GameState s) => starterShownOn(s)?.add(const Duration(days: starterDays));

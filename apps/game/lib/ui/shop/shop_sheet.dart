import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/purchase/purchase_providers.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/shop/iap_text.dart';
import 'package:pirate_dot/ui/shop/shop_data.dart';
import 'package:pirate_dot/ui/shop/shop_offers.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 유료 상점 화면 (쿵푸할매 상점처럼): 묶음(처음 한 번·편의·젬·월간 젬·패스·배 스킨)마다 상품 카드(색 칸 아이콘 · 이름 ·
// 구성 · 금빛 가격 버튼). 젬 팩 첫 구매는 '첫 구매 ×2' 리본, 구독은 'n일 남음', 산 영구 상품은 '보유 중'.
// 구매 결과(대기·실패·완료)는 PurchaseGate 토스트, 지급은 엔진(GrantPurchase → PurchaseGranted).

Future<void> showShop(BuildContext context) =>
    showPixelSheet<void>(context, maxHeight: 0.9, builder: (_) => const ShopSheet());

void buyProduct(WidgetRef ref, String id) => unawaited(ref.read(purchaseServiceProvider).buy(id));

class ShopSheet extends ConsumerWidget {
  const ShopSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offers = ref.watch(shopOffersProvider);
    final title = <ShopSection, String>{
      ShopSection.starter: l10n.uiShopSecStarter,
      ShopSection.convenience: l10n.uiShopSecConvenience,
      ShopSection.gems: l10n.uiShopSecGems,
      ShopSection.monthly: l10n.uiShopSecMonthly,
      ShopSection.pass: l10n.uiShopSecPass,
      ShopSection.skins: l10n.uiShopSecSkins,
    };
    return SingleChildScrollView(
      key: const Key('shop.sheet'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SubRibbon(l10n.uiShopTitle),
          if (offers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.uiShopEmpty,
                textAlign: TextAlign.center,
                style: Skin.text(15, color: Skin.sub),
              ),
            ),
          for (final sec in ShopSection.values)
            if (offers[sec] case final list? when list.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(title[sec]!, key: Key('shop.sec.${sec.name}'), style: Skin.bold(16)),
              const SizedBox(height: 6),
              switch (sec) {
                ShopSection.starter => const StarterOffer(),
                ShopSection.monthly => MonthlyGemOffer(offer: list.first),
                _ => _Grid(offers: list),
              },
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.offers});

  final List<ShopOffer> offers;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = box.maxWidth >= 520 ? 3 : 2;
      final w = (box.maxWidth - 10 * (cols - 1)) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 12,
        children: [
          for (final o in offers)
            SizedBox(
              width: w,
              child: ProductCard(offer: o),
            ),
        ],
      );
    },
  );
}

/// 상품 아이콘·칸 색.
(String, Color) offerLook(IapProduct p) => switch (shopSectionOf(p)) {
  ShopSection.starter => (UiSprites.chest, const Color(0xFFE0583D)),
  ShopSection.gems || ShopSection.monthly => (UiSprites.gem, partCellColors[1]),
  ShopSection.pass => (UiSprites.trophy, const Color(0xFFE0A83D)),
  ShopSection.skins => (UiSprites.flag, partCellColors[0]),
  ShopSection.convenience => switch (p.entitlements.map((e) => e.id).toSet()) {
    final r when r.length > 1 => (UiSprites.trophy, const Color(0xFFE0A83D)),
    final r when r.contains('speed') => (UiSprites.tailwind, partCellColors[2]),
    final r when r.contains('offline12') => (UiSprites.moon, partCellColors[2]),
    _ => (UiSprites.ad, partCellColors[2]),
  },
};

/// 상품 카드: 색 칸 아이콘 · 이름 · 구성 줄 · 금빛 가격 버튼(산 영구 상품은 '보유 중'). 첫 구매 ×2 리본 · 구독 남은 일수.
class ProductCard extends ConsumerWidget {
  const ProductCard({required this.offer, super.key});

  final ShopOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = offer.product;
    final (icon, color) = offerLook(p);
    return Stack(
      key: Key('shop.product.${p.id}'),
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          decoration: Skin.inset(radius: Skin.radiusCard),
          child: Column(
            children: [
              if (p.entitlements.map((e) => e.id).toSet().difference({'speed'}).isEmpty && p.entitlements.isNotEmpty)
                const SpeedCompare()
              else
                IconCell(color: color, size: 60, child: SkinIcon(icon, size: 40)),
              const SizedBox(height: 6),
              Text(
                iapName(l10n, p.nameKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Skin.bold(15),
              ),
              for (final line in offerLines(l10n, p, ref.watch(tablesProvider)).take(3))
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Skin.text(13, color: Skin.sub),
                ),
              const SizedBox(height: 6),
              if (offer.owned)
                Container(
                  key: Key('shop.owned.${p.id}'),
                  height: 44,
                  alignment: Alignment.center,
                  child: Text(l10n.uiShopOwned, style: Skin.bold(15, color: Skin.mintInk)),
                )
              else
                SkinButton(
                  key: Key('shop.buy.${p.id}'),
                  weight: PressWeight.heavy,
                  tone: SkinTone.gold,
                  height: 44,
                  onPressed: () => buyProduct(ref, p.id),
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.uiShopBuy(offer.price))),
                ),
            ],
          ),
        ),
        if (offer.firstDouble) _Corner(key: Key('shop.double.${p.id}'), text: l10n.uiShopFirstDouble, left: true),
        if (offer.daysLeft case final d?) _Corner(key: Key('shop.left.${p.id}'), text: l10n.uiShopDaysLeft(d)),
      ],
    );
  }
}

/// 카드 모서리 리본(왼쪽 위 빨강 = 첫 구매 ×2, 오른쪽 위 금빛 = 남은 일수).
class _Corner extends StatelessWidget {
  const _Corner({required this.text, this.left = false, super.key});

  final String text;
  final bool left;

  @override
  Widget build(BuildContext context) => Positioned(
    top: -6,
    left: left ? -6 : null,
    right: left ? null : -6,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: left ? const Color(0xFFE0283D) : null,
        gradient: left ? null : const LinearGradient(colors: [Skin.ribbonTop, Skin.ribbonBottom]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Skin.outline, width: 2),
      ),
      child: OutlineText(text, size: 13),
    ),
  );
}

/// 2배속 상품: 같은 장면 꺼짐/켜짐 비교 그림 두 칸(S3 assets/ui/speed_off·on, 사용자 2026-10-18 '사서 쓰고 싶게').
class SpeedCompare extends StatelessWidget {
  const SpeedCompare({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget panel(String asset, String label, {required bool on}) => Expanded(
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: on ? const Color(0xFFFFC83A) : Skin.cardEdge, width: on ? 2.5 : 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(asset, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Skin.bold(13, color: on ? Skin.goldInk : Skin.sub)),
        ],
      ),
    );
    return SizedBox(
      key: const Key('shop.speedCompare'),
      width: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          panel('assets/ui/speed_off.png', l10n.uiShopSpeedOff, on: false),
          const Padding(
            padding: EdgeInsets.only(top: 22),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: Skin.sub),
          ),
          panel('assets/ui/speed_on.png', l10n.uiShopSpeedOn, on: true),
        ],
      ),
    );
  }
}

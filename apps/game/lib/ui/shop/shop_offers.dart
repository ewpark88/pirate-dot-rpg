import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/shop/iap_text.dart';
import 'package:pirate_dot/ui/shop/shop_data.dart';
import 'package:pirate_dot/ui/shop/shop_sheet.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 상점의 넓은 칸: 스타터 팩(7일 남은 시간) · 월간 젬(오늘 받기) · 스타터 팩 1회 팝업.

/// 스타터 팩 넓은 카드: 큰 상자 · 구성 · 남은 시간(팝업을 본 뒤 7일) · 가격.
class StarterOffer extends ConsumerWidget {
  const StarterOffer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offer = ref.watch(shopOffersProvider)[ShopSection.starter]?.firstOrNull;
    if (offer == null) return const SizedBox.shrink();
    final ends = starterEnds(ref.watch(gameStateProvider));
    final left = ends?.difference(ref.watch(clockProvider).now());
    if (left != null && left.isNegative) return const SizedBox.shrink();
    return Container(
      key: const Key('shop.starter'),
      padding: const EdgeInsets.all(10),
      decoration: Skin.inset(radius: Skin.radiusCard),
      child: Row(
        children: [
          const IconCell(color: Color(0xFFE0583D), size: 72, child: SkinIcon(UiSprites.chest, size: 52)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(iapName(l10n, offer.product.nameKey), style: Skin.bold(17)),
                Text(
                  offerLines(l10n, offer.product, ref.watch(tablesProvider)).join(l10n.uiListSep),
                  style: Skin.text(13, color: Skin.sub),
                ),
                if (left != null)
                  Text(
                    l10n.uiShopEndsIn(left.inDays, left.inHours % 24),
                    key: const Key('shop.starter.ends'),
                    style: Skin.bold(13, color: Skin.danger),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (offer.owned)
            Text(l10n.uiShopOwned, style: Skin.bold(15, color: Skin.mintInk))
          else
            SkinButton(
              key: const Key('shop.buy.starter_pack'),
              tone: SkinTone.gold,
              onPressed: () => buyProduct(ref, offer.product.id),
              child: Text(l10n.uiShopBuy(offer.price)),
            ),
        ],
      ),
    );
  }
}

/// 월간 젬: 구독 중이면 남은 일수 + [오늘 젬 받기](ClaimGemSub, 하루 한 번), 아니면 상품 카드.
class MonthlyGemOffer extends ConsumerWidget {
  const MonthlyGemOffer({required this.offer, super.key});

  final ShopOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider).now();
    final canClaim = ref.watch(gameStateProvider.select((s) => canClaimGemSub(s, now)));
    final card = SizedBox(width: 200, child: ProductCard(offer: offer));
    if (offer.daysLeft == null) return Center(child: card);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: card),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              const SizedBox(height: 24),
              SkinButton(
                key: const Key('shop.gemSub.claim'),
                height: 56,
                onPressed: canClaim ? () => ref.read(commandSinkProvider).send(const ClaimGemSub()) : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(canClaim ? l10n.uiShopClaimToday : l10n.uiShopClaimedToday),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.uiShopDailyGems(ref.watch(tablesProvider).iap.gemSubDaily),
                style: Skin.text(13, color: Skin.sub),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 스타터 팩 1회 팝업 (노란 리본 창 + 넓은 카드 + [나중에]). 띄운 날부터 7일만 판다.
class StarterPackDialog extends ConsumerWidget {
  const StarterPackDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offer = ref.watch(shopOffersProvider)[ShopSection.starter]?.firstOrNull;
    return PixelDialog(
      key: const Key('shop.starterDialog'),
      title: offer == null ? l10n.uiShopTitle : iapName(l10n, offer.product.nameKey),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.uiShopStarterAsk, textAlign: TextAlign.center, style: Skin.text(16)),
          const SizedBox(height: 12),
          const StarterOffer(),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('shop.starter.later'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.uiShopLater, style: Skin.text(14, color: Skin.sub)),
          ),
        ],
      ),
    );
  }
}

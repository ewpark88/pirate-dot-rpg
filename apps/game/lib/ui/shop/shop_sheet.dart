import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/shop/shop_data.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

// 유료 상점 화면 골격 (개편 스타일 — 쿵푸할매 상점처럼): 상품 카드(색 칸 아이콘 · 이름 · 구성 · 금빛 가격 버튼),
// 할인 리본(왼쪽 위 빨강 사선), '인기' 배지, 구독 남은 기간 · '광고 없음' 배지 줄. 결제는 S5 어댑터가 오면 연결.

Future<void> showShop(BuildContext context) =>
    showPixelSheet<void>(context, maxHeight: 0.9, builder: (_) => const ShopSheet());

class ShopSheet extends ConsumerWidget {
  const ShopSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(shopCatalogProvider);
    final status = catalog.status();
    final products = catalog.products(l10n);
    return SingleChildScrollView(
      key: const Key('shop.sheet'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SubRibbon(l10n.uiShopTitle),
          const SizedBox(height: 8),
          // 구독 남은 기간 · 광고 없음.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (status.subDaysLeft case final d?)
                _StatusChip(
                  key: const Key('shop.sub'),
                  icon: Icons.workspace_premium_rounded,
                  text: l10n.uiShopSubLeft(d),
                ),
              if (status.noAds || status.subDaysLeft != null)
                _StatusChip(key: const Key('shop.noAds'), icon: Icons.block_rounded, text: l10n.uiShopNoAds),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth >= 520 ? 3 : 2;
              final w = (box.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 12,
                children: [
                  for (final p in products)
                    SizedBox(
                      width: w,
                      child: ProductCard(product: p),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Skin.navyPanel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Skin.outline, width: 2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFFFFD84A)),
        const SizedBox(width: 4),
        Flexible(child: OutlineText(text, size: 14, fit: true)),
      ],
    ),
  );
}

/// 상품 카드: 색 칸 아이콘 · 이름 · 구성 줄 · 금빛 가격 버튼, 할인 리본 · 인기 배지.
class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, this.onBuy, super.key});

  final ShopProduct product;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = product;
    final color = switch (p.kind) {
      ProductKind.starter => const Color(0xFFE0583D),
      ProductKind.gems => partCellColors[1],
      ProductKind.noAds => partCellColors[2],
      ProductKind.sub => const Color(0xFFE0A83D),
    };
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
              IconCell(color: color, size: 64, child: SkinIcon(p.icon, size: 44)),
              const SizedBox(height: 6),
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Skin.bold(15)),
              for (final c in p.contents)
                Text(
                  c,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Skin.text(13, color: Skin.sub),
                ),
              const SizedBox(height: 6),
              SkinButton(
                key: Key('shop.buy.${p.id}'),
                tone: SkinTone.gold,
                height: 44,
                onPressed: onBuy ?? () {},
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.uiShopBuy(p.price))),
              ),
            ],
          ),
        ),
        // 할인 리본 (왼쪽 위).
        if (p.discountPct case final d?)
          Positioned(
            top: -6,
            left: -6,
            child: Container(
              key: Key('shop.off.${p.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE0283D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Skin.outline, width: 2),
              ),
              child: OutlineText(l10n.uiShopOff(d), size: 13),
            ),
          ),
        if (p.best)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Skin.ribbonTop, Skin.ribbonBottom]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Skin.outline, width: 2),
              ),
              child: OutlineText(l10n.uiShopBest, size: 13),
            ),
          ),
      ],
    );
  }
}

/// 스타터 팩 1회 팝업 (노란 리본 창 + 큰 카드 + [나중에]).
class StarterPackDialog extends ConsumerWidget {
  const StarterPackDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final starter = ref.watch(shopCatalogProvider).products(l10n).firstWhere((p) => p.kind == ProductKind.starter);
    return PixelDialog(
      key: const Key('shop.starterDialog'),
      title: starter.name,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.uiShopStarterAsk, textAlign: TextAlign.center, style: Skin.text(16)),
          const SizedBox(height: 12),
          SizedBox(width: 200, child: ProductCard(product: starter)),
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

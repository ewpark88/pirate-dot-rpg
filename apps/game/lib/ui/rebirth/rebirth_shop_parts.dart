import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_text.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

/// 칸 그림 (기존 UI 그림 재사용 — 새 그림 없음).
const Map<String, String> _icons = {
  'startParts': UiSprites.tailwind,
  'discount': UiSprites.coin,
  'bossTime': UiSprites.flag,
  'offline': UiSprites.moon,
  'critChance': 'assets/ui/part_crowsnest.png',
  'critDamage': 'assets/ui/part_cannon.png',
  'fleetSlot': UiSprites.tabCrew,
  'pieceGain': UiSprites.tabMap,
  'fastSail': 'assets/ui/part_sail.png',
};

/// 상점 칸 하나.
class ShopTile extends StatelessWidget {
  const ShopTile({required this.item, required this.selected, required this.bumpKey, required this.onTap, super.key});

  final ShopItemVm item;
  final bool selected;

  /// 산 직후 통 튀기 (구매 번호 — 바뀌면 다시 튄다).
  final int? bumpKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dim = !item.unlocked;
    final border = selected ? Skin.primaryBottom : (item.affordable ? Skin.goldBottom : Colors.transparent);
    Widget tile = Semantics(
      button: true,
      selected: selected,
      label: shopName(l10n, item.id),
      child: GestureDetector(
        key: Key('rebirth.shop.item.${item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          decoration: BoxDecoration(
            color: dim ? Skin.plainBottom : (item.maxed ? const Color(0xFFE6F8EF) : Skin.cream),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 2.5),
          ),
          child: Column(
            children: [
              Opacity(
                opacity: dim ? 0.45 : 1,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Skin.skyDeep, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: SkinIcon(_icons[item.id] ?? UiSprites.star, size: 28),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                shopName(l10n, item.id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Skin.text(13, color: dim ? Skin.sub : Skin.ink),
              ),
              const SizedBox(height: 4),
              ShopPips(level: item.level, max: item.maxLevel),
              const SizedBox(height: 2),
              Text(
                item.maxed ? l10n.uiRebirthShopMax : l10n.uiRebirthShopLevel(item.level, item.maxLevel),
                style: Skin.text(12, color: item.maxed ? Skin.mintInk : Skin.sub),
              ),
            ],
          ),
        ),
      ),
    );
    if (item.affordable && !selected) tile = PixelDot(dotKey: Key('rebirth.shop.dot.${item.id}'), child: tile);
    if (bumpKey == null) return tile;
    return TweenAnimationBuilder<double>(
      key: ValueKey(bumpKey),
      tween: Tween(begin: 1.15, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: tile,
    );
  }
}

/// 레벨 점 줄 (최대 10칸) — 채운 만큼 금색.
class ShopPips extends StatelessWidget {
  const ShopPips({required this.level, required this.max, super.key});

  final int level;
  final int max;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 2,
    runSpacing: 2,
    alignment: WrapAlignment.center,
    children: [
      for (var i = 0; i < max; i++)
        Container(
          width: max > 5 ? 5 : 9,
          height: 5,
          decoration: BoxDecoration(
            color: i < level ? Skin.goldBottom : Skin.track,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
    ],
  );
}

/// 아래 칸: 고른 칸의 설명 · 레벨 a → a+1 · 효과 x → y · 구매.
class ShopDetail extends StatelessWidget {
  const ShopDetail({required this.item, required this.lockedLeft, required this.onBuy, super.key});

  final ShopItemVm? item;

  /// 고른 칸의 줄이 잠겼으면 더 써야 하는 조각.
  final int lockedLeft;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final it = item;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: Container(
        key: const Key('rebirth.shop.detail'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Skin.cream,
          borderRadius: BorderRadius.circular(Skin.radiusCard),
          border: Border.all(color: Skin.goldTop, width: 2),
        ),
        child: it == null
            ? Text(
                l10n.uiRebirthShopPick,
                textAlign: TextAlign.center,
                style: Skin.text(15, color: Skin.sub),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(shopName(l10n, it.id), style: Skin.text(19)),
                  const SizedBox(height: 2),
                  Text(shopDesc(l10n, it), style: Skin.text(14, color: Skin.sub)),
                  const SizedBox(height: 8),
                  if (it.maxed)
                    Text(
                      '${l10n.uiRebirthShopMax} · ${shopFx(l10n, it.id, it.effectNow)}',
                      style: Skin.text(16, color: Skin.mintInk),
                    )
                  else ...[
                    Text(l10n.uiRebirthShopNext(it.level, it.level + 1), style: Skin.text(15)),
                    Text(
                      l10n.uiRebirthShopEffect(
                        shopFx(l10n, it.id, it.effectNow),
                        shopFx(l10n, it.id, it.effectNext ?? it.effectNow),
                      ),
                      style: Skin.text(15, color: Skin.mintInk),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SkinButton(
                        key: const Key('rebirth.shop.buy'),
                        tone: SkinTone.gold,
                        height: 52,
                        onPressed: it.affordable ? onBuy : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SkinIcon(UiSprites.tabMap),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                it.unlocked ? l10n.uiRebirthShopBuy(it.cost!) : l10n.uiRebirthRowLocked(lockedLeft),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

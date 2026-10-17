import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/guide/once_tip.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_shop_parts.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_text.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';

/// 보물지도 상점을 띄운다 (항해 탭 환생 카드의 버튼).
Future<void> openRebirthShop(BuildContext context) =>
    showPixelSheet<void>(context, maxHeight: 0.92, builder: (_) => const RebirthShopSheet());

/// 보물지도 상점 (스펙 platform-rebirth-v2 7장 ④): 3줄 트리, 잠긴 줄은 '조각 N개를 더 쓰면 열림' 막대.
/// 칸을 누르면 아래 칸에 '레벨 a → a+1 · 효과 x → y' + 구매 버튼.
class RebirthShopSheet extends ConsumerStatefulWidget {
  const RebirthShopSheet({super.key});

  @override
  ConsumerState<RebirthShopSheet> createState() => _RebirthShopSheetState();
}

class _RebirthShopSheetState extends ConsumerState<RebirthShopSheet> {
  String? _picked;

  /// 방금 산 칸 — 한 번 통 튄다.
  String? _bumped;
  var _bumpSeq = 0;

  void _buy(ShopItemVm item) {
    if (!ref.read(rebirthV2Provider).buy(item.id)) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _bumped = item.id;
      _bumpSeq++;
    });
    showSkinToast(context, l10n.uiRebirthShopBought(item.level + 1, shopName(l10n, item.id)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shop = ref.watch(rebirthShopProvider);
    final picked = shop.items.where((i) => i.id == _picked).firstOrNull;
    return Column(
      key: const Key('rebirth.shop'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // k2: 노란 소제목 리본 + 남색 조각 알약.
            Expanded(child: SubRibbon(l10n.uiRebirthShop)),
            const SizedBox(width: 8),
            _PiecePill(count: shop.pieces),
          ],
        ),
        // 처음 열 때 옥토 한 마디: 철갑판(가이드 v3).
        OnceTip(id: 'tip.ironDeck', text: l10n.uiTipIronDeck),
        const SizedBox(height: 10),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var row = 1; row <= 3; row++) ...[
                  if (row > 1) _Connector(lit: shop.toUnlock(row) == 0),
                  _Row(
                    row: row,
                    shop: shop,
                    picked: _picked,
                    bumped: _bumped,
                    bumpSeq: _bumpSeq,
                    onPick: (id) => setState(() => _picked = id),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ShopDetail(
          item: picked,
          lockedLeft: picked == null ? 0 : shop.toUnlock(picked.row),
          onBuy: picked == null ? null : () => _buy(picked),
        ),
      ],
    );
  }
}

class _PiecePill extends StatelessWidget {
  const _PiecePill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('rebirth.shop.pieces'),
    padding: const EdgeInsets.fromLTRB(6, 3, 12, 3),
    decoration: BoxDecoration(
      color: Skin.navyPanel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Skin.outline, width: Skin.outlineWidth),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SkinIcon(UiSprites.shard, size: 22),
        const SizedBox(width: 4),
        OutlineText(AppLocalizations.of(context).uiRebirthShopPieces(count), size: 15, tone: OutlineTone.gold),
      ],
    ),
  );
}

/// 줄 사이 세로 이음선 — 열린 줄로 이어지면 금색.
class _Connector extends StatelessWidget {
  const _Connector({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 14,
    decoration: BoxDecoration(
      color: lit ? Skin.goldBottom : Skin.track,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.shop,
    required this.picked,
    required this.bumped,
    required this.bumpSeq,
    required this.onPick,
  });

  final int row;
  final ShopVm shop;
  final String? picked;
  final String? bumped;
  final int bumpSeq;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = shop.items.where((i) => i.row == row).toList();
    final left = shop.toUnlock(row);
    final locked = left > 0;
    final need = shop.unlockAt(row);
    return Container(
      key: Key('rebirth.shop.row.$row'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      // 잠긴 줄은 옅은 회보라(k2의 Skin.track은 남색이라 잠김 안내 글자가 묻힌다).
      decoration: Skin.inset(fill: locked ? const Color(0xFFD3D1EA) : Skin.insetFill, radius: Skin.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.uiRebirthRow(row), style: Skin.bold(15, color: Skin.outline)),
              if (locked) ...[
                const SizedBox(width: 8),
                const SkinIcon(UiSprites.lock),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.uiRebirthRowLocked(left),
                    key: Key('rebirth.shop.locked.$row'),
                    style: Skin.text(14, color: Skin.sub),
                  ),
                ),
              ],
            ],
          ),
          if (locked) ...[
            const SizedBox(height: 6),
            PixelBar(value: (shop.spentTotal / need).clamp(0.0, 1.0), fill: Skin.goldBottom),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (k, item) in items.indexed) ...[
                if (k > 0) const SizedBox(width: 8),
                Expanded(
                  child: ShopTile(
                    item: item,
                    selected: picked == item.id,
                    bumpKey: bumped == item.id ? bumpSeq : null,
                    onTap: () => onPick(item.id),
                  ),
                ),
              ],
              // 2칸 줄도 3칸 줄과 칸 크기를 맞춘다.
              for (var k = items.length; k < 3; k++) ...[const SizedBox(width: 8), const Expanded(child: SizedBox())],
            ],
          ),
        ],
      ),
    );
  }
}

/// 상점 열기 (짧은 이름 — 다른 화면에서 쓴다).
void showRebirthShop(BuildContext context) => unawaited(openRebirthShop(context));

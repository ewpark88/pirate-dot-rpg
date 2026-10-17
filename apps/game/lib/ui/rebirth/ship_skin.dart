import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/rebirth/ship_skin_entries.dart';
import 'package:pirate_dot/ui/ship/ship_look.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 배 스킨 칸 (환생 v2 스펙 7장 ⑤ + 새 스킨 7종 docs/specs/economy-ship-skins.md) — 목록은 ship_skin_entries.dart.

/// 배 탭의 작은 '배 스킨' 버튼.
class ShipSkinButton extends ConsumerWidget {
  const ShipSkinButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 잠긴 스킨도 얻는 방법을 보여 주니 늘 보인다(새 스킨 7종, S1 2026-10-17).
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.uiShipSkin,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('ship.skin'),
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(showPixelSheet<void>(context, builder: (_) => const ShipSkinSheet())),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 2, 12, 2),
            decoration: Skin.inset(radius: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ShipLookPreview(size: 40),
                const SizedBox(width: 4),
                Text(l10n.uiShipSkin, style: Skin.text(15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 배 스킨 칸 (k2): 위 = 고른 스킨 큰 미리보기 · 이름 · 얻는 방법/진행 · [입기]/[조각으로 사기], 아래 = 등급 칸 격자.
class ShipSkinSheet extends ConsumerStatefulWidget {
  const ShipSkinSheet({super.key});

  @override
  ConsumerState<ShipSkinSheet> createState() => _ShipSkinSheetState();
}

class _ShipSkinSheetState extends ConsumerState<ShipSkinSheet> {
  /// 미리 보는 스킨 (처음엔 지금 입은 것). '' = 기본 배.
  String? _pick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final equipped = ref.watch(shipSkinProvider).equipped;
    // 스킨·조각·진행이 바뀔 때만 다시 짓는다.
    ref.watch(
      gameStateProvider.select(
        (s) => '${s.ship.skinsOwned.join(',')}|${s.wallet.mapPieces}|${s.collection.length}|${s.progress.bestStage}',
      ),
    );
    final entries = skinEntries(l10n, ref.read(gameStateProvider), ref.read(tablesProvider));
    final pick = _pick ?? equipped ?? '';
    final sel = entries.firstWhere((e) => (e.id ?? '') == pick, orElse: () => entries.first);
    final control = ref.read(rebirthV2Provider);
    return SingleChildScrollView(
      key: const Key('ship.skin.sheet'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SubRibbon(l10n.uiShipSkin),
          const SizedBox(height: 8),
          _SkinPreview(
            entry: sel,
            equipped: (sel.id ?? '') == (equipped ?? ''),
            pieces: ref.read(gameStateProvider).wallet.mapPieces,
            onWear: () => control.selectSkin(sel.id),
            onBuy: () => ref.read(commandSinkProvider).send(BuySkin(sel.id!)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final e in entries)
                _SkinTile(
                  key: Key('ship.skin.${e.id ?? 'default'}'),
                  entry: e,
                  equipped: (e.id ?? '') == (equipped ?? ''),
                  picked: (e.id ?? '') == pick,
                  onTap: () => setState(() => _pick = e.id ?? ''),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 고른 스킨 큰 미리보기 + 행동 버튼.
class _SkinPreview extends StatelessWidget {
  const _SkinPreview({
    required this.entry,
    required this.equipped,
    required this.pieces,
    required this.onWear,
    required this.onBuy,
  });

  final SkinEntry entry;
  final bool equipped;
  final int pieces;
  final VoidCallback onWear;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final e = entry;
    final price = e.price;
    final action = equipped
        ? Text(
            l10n.uiSkinEquipped,
            key: const Key('ship.skin.equipped'),
            style: Skin.bold(16, color: Skin.mintInk),
          )
        : e.owned
        ? SkinButton(key: const Key('ship.skin.wear'), onPressed: onWear, child: Text(l10n.uiSkinWear))
        : price != null
        ? SkinButton(
            key: const Key('ship.skin.buy'),
            tone: SkinTone.gold,
            onPressed: pieces >= price ? onBuy : null,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.uiSkinBuy(price))),
          )
        : const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: Skin.inset(radius: Skin.radiusCard),
      child: Row(
        children: [
          ShipLookPreview(key: const Key('ship.skin.preview'), useSkin: true, skin: e.id, size: 110),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: Skin.bold(19)),
                if (!e.owned) ...[
                  const SizedBox(height: 4),
                  Text(
                    e.how,
                    key: const Key('ship.skin.how'),
                    style: Skin.text(15, color: Skin.sub),
                  ),
                  const SizedBox(height: 4),
                  SkinBar(value: e.need == 0 ? 0 : e.now / e.need, color: Skin.goldBottom),
                  Text(l10n.uiSkinProgress(e.now.clamp(0, e.need), e.need), style: Skin.text(13, color: Skin.sub)),
                ],
                const SizedBox(height: 8),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 격자 칸: 등급색 네모(가진 것 = 파랑 · 입은 것 = 금 · 잠김 = 회보라 + 자물쇠) + 이름.
class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.entry,
    required this.equipped,
    required this.picked,
    required this.onTap,
    super.key,
  });

  final SkinEntry entry;
  final bool equipped;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final color = equipped ? Skin.goldBottom : (e.owned ? partCellColors[1] : const Color(0xFF8E8CB4));
    return Semantics(
      button: true,
      selected: picked,
      label: e.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 82,
          child: Column(
            children: [
              AnimatedScale(
                scale: picked ? 1.08 : 1,
                duration: const Duration(milliseconds: 160),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconCell(
                      color: color,
                      size: 72,
                      child: Opacity(
                        opacity: e.owned ? 1 : 0.4,
                        child: ShipLookPreview(useSkin: true, skin: e.id, size: 56),
                      ),
                    ),
                    if (!e.owned) const Positioned(right: -4, bottom: -4, child: SkinIcon(UiSprites.lock, size: 22)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                e.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: picked ? Skin.bold(13) : Skin.text(13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

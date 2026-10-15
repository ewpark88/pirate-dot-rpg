import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_text.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/rebirth/skin_preview_ship.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

// 환생 v2 꾸미기: 배 스킨 고르기(스펙 7장 ⑤)와 칭호(⑥).

/// 배 탭의 작은 '배 스킨' 버튼 (스킨이 하나라도 있으면 보인다).
class ShipSkinButton extends ConsumerWidget {
  const ShipSkinButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skins = ref.watch(shipSkinProvider);
    if (skins.owned.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final equipped = skinDefs.where((s) => s.id == skins.equipped).firstOrNull;
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
            decoration: BoxDecoration(
              color: Skin.card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: Skin.shadowSmall,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SkinPreviewShip(skin: equipped, size: 40),
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

/// 배 스킨 고르기: 가로 목록, 잠긴 것은 '환생 N회'.
class ShipSkinSheet extends ConsumerWidget {
  const ShipSkinSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final skins = ref.watch(shipSkinProvider);
    final control = ref.read(rebirthV2Provider);
    return Column(
      key: const Key('ship.skin.sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.uiShipSkin, style: Skin.text(22)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _SkinTile(
                key: const Key('ship.skin.default'),
                skin: null,
                name: l10n.uiShipSkinDefault,
                owned: true,
                equipped: skins.equipped == null,
                onTap: () => control.selectSkin(null),
              ),
              for (final s in skinDefs)
                _SkinTile(
                  key: Key('ship.skin.${s.id}'),
                  skin: s,
                  name: skinName(l10n, s.id),
                  owned: skins.owned.contains(s.id),
                  equipped: skins.equipped == s.id,
                  onTap: () => control.selectSkin(s.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.skin,
    required this.name,
    required this.owned,
    required this.equipped,
    required this.onTap,
    super.key,
  });

  final SkinDef? skin;
  final String name;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Semantics(
        button: owned,
        selected: equipped,
        label: name,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: owned ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 112,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: owned ? Skin.cream : Skin.track,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: equipped ? Skin.primaryBottom : Colors.transparent, width: 3),
              boxShadow: owned ? Skin.shadowSmall : null,
            ),
            child: Column(
              children: [
                Opacity(
                  opacity: owned ? 1 : 0.35,
                  child: SkinPreviewShip(skin: skin, size: 84),
                ),
                const SizedBox(height: 6),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Skin.text(14)),
                const SizedBox(height: 2),
                if (!owned)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SkinIcon(UiSprites.lock),
                      const SizedBox(width: 2),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(l10n.uiSkinLocked(skin!.rebirths), style: Skin.text(13, color: Skin.sub)),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    equipped ? l10n.uiSkinEquipped : ' ',
                    style: Skin.text(13, color: Skin.primaryEdge),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

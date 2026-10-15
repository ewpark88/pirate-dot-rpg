import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 보물 바다 항로 고르기 (환생 3회부터): 끄기 · 1~3해역, 고르면 체력·조각 배수.
class TreasureRoute extends ConsumerWidget {
  const TreasureRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(treasureSeaCountProvider);
    if (count == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final sea = ref.watch(rebirthV2Provider.select((s) => s.sea));
    final control = ref.read(rebirthV2Provider.notifier);
    Widget chip(int? value, String label) {
      final on = sea == value;
      return Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          key: Key('rebirth.sea.${value ?? 0}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => control.setTreasureRoute(value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: on ? Skin.primaryBottom : Skin.plainBottom,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? Skin.primaryEdge : Skin.plainEdge, width: 2),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(label, style: Skin.text(15, color: on ? Colors.white : Skin.ink)),
            ),
          ),
        ),
      );
    }

    final info = sea == null ? null : treasureSeas[sea - 1];
    return Container(
      key: const Key('rebirth.treasure'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4CF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Skin.goldBottom, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.uiRebirthTreasureRoute, style: Skin.text(16, color: Skin.goldInk)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              chip(null, l10n.uiRebirthTreasureOff),
              for (var i = 1; i <= count; i++) chip(i, l10n.uiRebirthTreasureSea(i)),
            ],
          ),
          if (info != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.uiRebirthTreasureInfo(info.hp.toStringAsFixed(1), info.pieces.toStringAsFixed(1)),
              key: const Key('rebirth.treasure.info'),
              style: Skin.text(14, color: Skin.goldInk),
            ),
          ],
        ],
      ),
    );
  }
}

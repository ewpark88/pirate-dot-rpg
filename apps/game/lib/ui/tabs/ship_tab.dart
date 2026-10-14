import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 배 탭: 부위 5줄 (이름·레벨·현재 효과·강화 비용 버튼). 효과·비용은 경제 함수로만 구한다 (설계서 4.2).
// TODO(ui): 꾹 눌러 연속 강화, 자동 강화 토글, 배 등급 진행 막대 — 다음 계획.
class ShipTab extends ConsumerWidget {
  const ShipTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    return ListView(
      children: [for (final def in tables.shipParts.parts) _PartRow(def: def)],
    );
  }
}

class _PartRow extends ConsumerWidget {
  const _PartRow({required this.def});

  final ShipPartDef def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 골드는 틱마다 바뀌므로 "살 수 있나"만 구독한다.
    final (level, affordable) = ref.watch(
      gameStateProvider.select((s) {
        final lv = s.ship.parts[def.id] ?? 0;
        return (lv, s.wallet.gold >= partCost(def, lv));
      }),
    );
    final max = def.maxLevel;
    final maxed = max != null && level >= max;
    final cost = partCost(def, level);

    return ListTile(
      dense: true,
      title: Text(tableText(l10n, def.nameKey)),
      subtitle: Text(max == null ? l10n.uiLevel(level) : l10n.uiLevelMax(level, max)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(partEffectText(l10n, def, partEffect(def, level)), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 12),
          TutorialSpot(
            id: 'ship.upgrade.${def.id}',
            child: FilledButton.icon(
              key: Key('ship.upgrade.${def.id}'),
              onPressed: maxed || !affordable ? null : () => ref.read(commandSinkProvider).send(UpgradePart(def.id)),
              icon: maxed ? null : const Icon(Icons.monetization_on, size: 16),
              label: Text(maxed ? l10n.uiShipMaxed : cost.format()),
            ),
          ),
        ],
      ),
    );
  }
}

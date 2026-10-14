import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// 10연 소환.
const _summonTen = 10;

/// 소환 탭: 1회·10회 버튼(젬 비용), 천장 진행 막대, 등급 확률표 (설계서 4.3, 9.3 확률 공개).
// TODO(ui): 광고 무료 소환(남은 횟수), 증표 상점 — 다음 계획.
class SummonTab extends ConsumerWidget {
  const SummonTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    // 비용은 상태에 따라 달라진다 (첫 10연 무료) — 경제 summonCostFor로만 구한다.
    final (costOne, costTen, canOne, canTen, pity) = ref.watch(
      gameStateProvider.select(
        (s) => (
          summonCostFor(s, tables, 1),
          summonCostFor(s, tables, _summonTen),
          canSummon(s, tables, 1),
          canSummon(s, tables, _summonTen),
          s.pityCount,
        ),
      ),
    );
    final rarities = tables.rarities;
    final pityRarity = rarities.rarities.firstWhere((r) => r.id == rarities.pityMinRarity);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            for (final (key, count, label) in [
              ('summon.one', 1, l10n.uiSummonOne),
              ('summon.ten', _summonTen, l10n.uiSummonTen),
            ]) ...[
              Expanded(
                child: _SummonButton(
                  buttonKey: Key(key),
                  label: label,
                  cost: count == 1 ? costOne : costTen,
                  onPressed: (count == 1 ? canOne : canTen)
                      ? () => ref.read(commandSinkProvider).send(Summon(count: count))
                      : null,
                ),
              ),
              if (count == 1) const SizedBox(width: 12),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.uiSummonPity(rarities.pityCount, tableText(l10n, pityRarity.nameKey))),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: LinearProgressIndicator(value: pity / rarities.pityCount, minHeight: 8)),
            const SizedBox(width: 8),
            Text(l10n.uiSummonPityProgress(pity, rarities.pityCount)),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.uiSummonRates, style: Theme.of(context).textTheme.titleSmall),
        for (final r in rarities.rarities.where((r) => r.summonRate > 0)) _RateRow(rarity: r),
      ],
    );
  }
}

class _SummonButton extends StatelessWidget {
  const _SummonButton({required this.buttonKey, required this.label, required this.cost, required this.onPressed});

  final Key buttonKey;
  final String label;
  final int cost;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    key: buttonKey,
    onPressed: onPressed,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (cost == 0)
          Text(AppLocalizations.of(context).uiSummonFree, key: const Key('summon.free'))
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.diamond, size: 14),
              const SizedBox(width: 2),
              Text(cost.toString()),
            ],
          ),
      ],
    ),
  );
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.rarity});

  final RarityDef rarity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: Key('summon.rate.${rarity.id}'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: rarityColor(rarity)),
          const SizedBox(width: 6),
          Expanded(child: Text(tableText(l10n, rarity.nameKey))),
          Text(percentText(l10n, rarity.summonRate)),
        ],
      ),
    );
  }
}

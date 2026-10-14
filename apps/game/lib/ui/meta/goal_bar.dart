import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// HUD 아래 ‘다음 목표’ 한 줄 (설계서 4.5, 4.12 목표 막대). 목표가 없으면 아무것도 그리지 않는다.
class GoalBar extends ConsumerWidget {
  const GoalBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextGoalProvider);
    final goal = ref.watch(
      gameStateProvider.select((s) {
        final g = next(s);
        return g == null ? null : (g.kind, g.id, g.remaining, g.progress);
      }),
    );
    if (goal == null) return const SizedBox.shrink();
    final (kind, id, remaining, progress) = goal;
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final text = switch (kind) {
      GoalKind.shipTier => l10n.uiGoalShipTier(
        remaining,
        tableText(l10n, tables.shipTiers.tiers.firstWhere((t) => t.id == id).nameKey),
      ),
      GoalKind.partMilestone => l10n.uiGoalPartMilestone(
        remaining,
        tableText(l10n, tables.shipParts.byId(id!).nameKey),
      ),
      GoalKind.collection => l10n.uiGoalCollection(remaining),
      GoalKind.rebirth => l10n.uiGoalRebirth(remaining),
    };

    return Padding(
      key: const Key('goal'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, size: 14),
          const SizedBox(width: 4),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: LinearProgressIndicator(value: progress, minHeight: 6)),
        ],
      ),
    );
  }
}

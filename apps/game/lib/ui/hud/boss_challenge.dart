import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 파밍 중(보스를 못 잡아 제자리 항해)이면 전장 위에 ‘파밍 중’과 보스 도전 버튼 (설계서 4.1-4).
class BossChallenge extends ConsumerWidget {
  const BossChallenge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(
      gameStateProvider.select((s) => s.progress.farming && !(s.battle?.bossActive ?? false)),
    );
    if (!show) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Chip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.autorenew, size: 16),
          label: Text(l10n.uiFarming),
        ),
        const SizedBox(height: 4),
        FilledButton.icon(
          key: const Key('boss.challenge'),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => ref.read(commandSinkProvider).send(const ChallengeBoss()),
          icon: const Icon(Icons.flag),
          label: Text(l10n.uiBossChallenge),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 항해 탭 (설계서 4.12): 지금 해역·스테이지·최고 스테이지, 환생(보물지도) 카드.
// TODO(ui): 해역 지도(해역 6개 진행), 패널 접어 전장 크게 보기 — 다음 계획.
class VoyageTab extends ConsumerWidget {
  const VoyageTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final (stage, wave, best) = ref.watch(
      gameStateProvider.select((s) => (s.progress.stage, s.progress.wave, s.progress.bestStage)),
    );
    final region = tables.regions.regionAt(stage);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const Icon(Icons.sailing),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${tableText(l10n, region.nameKey)} · ${l10n.uiHudStage(stage, wave)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        Text(l10n.uiBestStage(best)),
        const SizedBox(height: 12),
        const RebirthCard(),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 보스전 약점 표시 (설계서 4.11): 보스 이름 + ‘약점’ + 잘 먹히는 계열 칩. 보는 것만 — 편성은 자동이다.
/// 약점이 없는 보스·보스전이 아닐 때는 아무것도 그리지 않는다.
class BossWeakness extends ConsumerWidget {
  const BossWeakness({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    // 지금 보스 = 전장의 보스 적의 kind (regions.json bosses id).
    final bossId = ref.watch(
      gameStateProvider.select((s) {
        final b = s.battle;
        if (b == null || !b.bossActive) return null;
        for (final e in b.enemies) {
          if (e.boss) return e.kind;
        }
        return null;
      }),
    );
    final boss = bossId == null ? null : tables.regions.bosses[bossId];
    if (boss == null || boss.weakFamilies.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white);

    return Container(
      key: const Key('boss.weak'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tableText(l10n, boss.nameKey), style: small?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.uiBossWeak, style: small),
              for (final f in boss.weakFamilies) ...[
                const SizedBox(width: 4),
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  label: Text(tableText(l10n, tables.skills.byId(f).nameKey)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

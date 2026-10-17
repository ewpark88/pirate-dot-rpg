import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart';
import 'package:pirate_dot/ui/dex/monster_dex_data.dart';
import 'package:pirate_dot/ui/hud/fever_drama.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 바다 괴물 도감 화면 골격 (S1 2026-10-16): 항해 탭 '보물지도' 옆 카드 → 시트(해역마다 잡몹·보스 칸).
// 만난 적은 실루엣, 처치하면 모습·이름 공개, 처치 수 · 첫 처치 보상 젬.

/// 도감 시트 열기 (항해 탭 카드·첫 처치 토스트의 '도감').
Future<void> showMonsterDex(BuildContext context) =>
    showPixelSheet<void>(context, maxHeight: 0.85, builder: (_) => const MonsterDexSheet());

/// 항해 탭 카드: 제목 · n/m · 진행 막대 → 누르면 도감 시트.
class MonsterDexCard extends ConsumerWidget {
  const MonsterDexCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dex = ref.watch(monsterDexProvider);
    final all = [for (final r in dex) ...r.entries];
    final done = all.where((e) => e.defeated).length;
    return GestureDetector(
      key: const Key('dex.card'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(showMonsterDex(context)),
      child: PixelFrame(
        padding: 6,
        child: Row(
          children: [
            const MonsterSprite(id: 'crab', size: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: SubRibbon(l10n.uiDexTitle)),
                      Text(l10n.uiDexCount(done, all.length), key: const Key('dex.count'), style: Skin.text(15)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: all.isEmpty ? 0 : done / all.length,
                      minHeight: 6,
                      backgroundColor: Skin.track,
                      color: Skin.mint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Skin.sub),
          ],
        ),
      ),
    );
  }
}

/// 잡몹 그림 (`enemies/td_<id>.png` 첫 칸). [shadow]면 검은 실루엣.
class MonsterSprite extends StatelessWidget {
  const MonsterSprite({required this.id, this.size = 40, this.shadow = false, super.key});

  final String id;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final img = SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: size * 2,
          child: Image.asset(
            'assets/enemies/td_$id.png',
            width: size * 2,
            height: size,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    return shadow
        ? ColorFiltered(colorFilter: const ColorFilter.mode(Color(0xFF2B3550), BlendMode.srcIn), child: img)
        : img;
  }
}

/// 도감 시트: 해역마다 머리(이름 · n/m) + 칸 격자.
class MonsterDexSheet extends ConsumerWidget {
  const MonsterDexSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dex = ref.watch(monsterDexProvider);
    return ListView(
      key: const Key('dex.sheet'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        Text(l10n.uiDexTitle, style: Theme.of(context).textTheme.titleLarge),
        Text(l10n.uiDexHint, style: Skin.text(13, color: Skin.sub)),
        for (final r in dex) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(tableText(l10n, r.region.nameKey), style: Skin.text(16))),
              Text(
                l10n.uiDexCount(r.entries.where((e) => e.defeated).length, r.entries.length),
                style: Skin.text(14, color: Skin.sub),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, box) {
              final cols = (box.maxWidth / 84).floor().clamp(3, 8);
              final w = (box.maxWidth - 6 * (cols - 1)) / cols;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in r.entries)
                    SizedBox(
                      width: w,
                      child: _DexTile(entry: e),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _DexTile extends ConsumerWidget {
  const _DexTile({required this.entry});

  final DexEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final e = entry;
    final known = e.defeated;
    final name = !known ? l10n.uiDexUnknown : (e.boss ? bossName(l10n, ref, e.id) : monsterName(l10n, e.id));
    final kills = e.kills;
    return Container(
      key: Key('dex.tile.${e.id}'),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      decoration: BoxDecoration(
        color: known ? Skin.card : Skin.track,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: e.boss ? feverGold : Skin.cardEdge, width: e.boss ? 2 : 1.5),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Center(
              child: !e.met
                  ? const Icon(Icons.help_outline_rounded, size: 28, color: Skin.sub)
                  : (e.boss
                        ? ColorFiltered(
                            colorFilter: known
                                ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                                : const ColorFilter.mode(Color(0xFF2B3550), BlendMode.srcIn),
                            child: BossPortrait(bossId: e.id, size: 44),
                          )
                        : MonsterSprite(id: e.id, shadow: !known)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Skin.text(12, color: known ? Skin.ink : Skin.sub),
          ),
          Text(
            known
                ? l10n.uiDexKills(kills)
                : l10n.uiDexFirstKill(dexFirstKillGems(ref.watch(tablesProvider), boss: e.boss)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Skin.text(10, color: known ? Skin.sub : Skin.primaryEdge),
          ),
        ],
      ),
    );
  }
}

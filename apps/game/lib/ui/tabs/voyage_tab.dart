import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/hud/boss_weakness.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// ‘시간당’ 오프라인 골드를 구할 때 쓰는 가짜 경과 (받을 때와 같은 계산으로 1시간치).
const _hour = Duration(hours: 1);

/// 항해 탭 (설계서 4.12): 해역 진행·해역 보스 미리보기, 오프라인·순풍 상태, 환생(보물지도) 카드.
// TODO(ui): 해역 지도 그림(해역 6개), 패널 접어 전장 크게 보기 — 다음 계획.
class VoyageTab extends ConsumerWidget {
  const VoyageTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final best = ref.watch(gameStateProvider.select((s) => s.progress.bestStage));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _RegionCard(),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text(l10n.uiBestStage(best)),
        ),
        const SizedBox(height: 8),
        const _StatusLines(),
        const SizedBox(height: 8),
        const RebirthCard(),
      ],
    );
  }
}

/// 해역 카드: 이름·해역 안 진행·해역 보스까지·보스 이름과 약점·다음 해역.
class _RegionCard extends ConsumerWidget {
  const _RegionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final regions = ref.watch(tablesProvider).regions;
    final (stage, wave) = ref.watch(gameStateProvider.select((s) => (s.progress.stage, s.progress.wave)));
    final per = regions.stagesPerRegion;
    // 해역 보스는 해역 마지막 스테이지(per의 배수)에 나온다 (regions.bossAt).
    final inRegion = (stage - 1) % per + 1;
    final toBoss = per - inRegion;
    final boss = regions.bossAt(stage + toBoss);
    final next = regions.regionAt(stage + toBoss + 1);

    return PixelFrame(
      key: const Key('voyage.region'),
      padding: 6,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sailing),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${tableText(l10n, regions.regionAt(stage).nameKey)} · ${l10n.uiHudStage(stage, wave)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(l10n.uiRegionProgress(inRegion, per)),
              ],
            ),
            const SizedBox(height: 4),
            PixelBar(value: inRegion / per, fill: PixelPalette.gold),
            const SizedBox(height: 8),
            Text(toBoss == 0 ? l10n.uiRegionBossNow : l10n.uiRegionBossIn(toBoss)),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(tableText(l10n, boss.nameKey), style: const TextStyle(fontWeight: FontWeight.bold)),
                if (boss.weakFamilies.isNotEmpty) WeakChips(boss: boss),
              ],
            ),
            Text(l10n.uiNextRegion(tableText(l10n, next.nameKey)), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// 오프라인 시간당 골드·최대 시간, 순풍 남은 시간.
class _StatusLines extends ConsumerWidget {
  const _StatusLines();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final now = ref.watch(clockProvider).now();
    // 받을 때와 같은 계산(경제 offlinePreview)으로 1시간치를 미리 본다.
    final perHour = ref.watch(
      gameStateProvider.select((s) => offlinePreview(s, tables, s.savedAt.add(_hour))?.gold),
    );
    final left = ref.watch(gameStateProvider.select((s) => tailwindRemaining(s, now)));
    final mult = adDef(tables, AdPlacement.tailwind).reward.number('goldMultiplier');
    final maxHours = Duration(seconds: tables.meta.offlineMaxSec).inHours;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.bedtime_outlined),
          title: Text(l10n.uiOfflineRate((perHour ?? BigNum.zero).format(), maxHours)),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.air),
          title: Text(
            left > Duration.zero ? l10n.uiTailwindStatus(shortDecimal(mult), remainingText(left)) : l10n.uiTailwindOff,
          ),
        ),
      ],
    );
  }
}

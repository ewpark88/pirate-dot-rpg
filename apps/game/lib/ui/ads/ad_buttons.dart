import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

// 장치별 광고 버튼. 버튼에는 항상 이득을 숫자로 쓴다(설계서 4.6). 보상 값은 ads.json에서 읽는다.

/// 보물상자: 골드 ×5 · 젬 30 중 선택 (사용자 결정 2026-10-14).
class ChestAdButtons extends ConsumerWidget {
  const ChestAdButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adOfferProvider(AdPlacement.chest))) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final reward = adDef(tables, AdPlacement.chest).reward;
    final mult = reward.number('value');
    final rewardOf = ref.watch(chestRewardProvider);
    final base = ref.watch(gameStateProvider.select(rewardOf));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdButton(
          placement: AdPlacement.chest,
          choice: 'gold',
          label: l10n.uiAdChestGold(base?.times(mult).format() ?? '', shortDecimal(mult)),
        ),
        const SizedBox(width: 4),
        AdButton(placement: AdPlacement.chest, choice: 'gems', label: l10n.uiAdChestGems(reward.integer('altGems'))),
      ],
    );
  }
}

/// 순풍: ‘30분 ×2’.
class TailwindAdButton extends ConsumerWidget {
  const TailwindAdButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reward = adDef(ref.watch(tablesProvider), AdPlacement.tailwind).reward;
    final minutes = Duration(seconds: reward.integer('durationSec')).inMinutes;
    return AdButton(
      placement: AdPlacement.tailwind,
      label: AppLocalizations.of(context).uiAdTailwind(minutes, shortDecimal(reward.number('goldMultiplier'))),
    );
  }
}

/// 함포 지원 (보스 실패로 파밍 중): ‘피해 +30% · 30초’.
class BossSupportAdButton extends ConsumerWidget {
  const BossSupportAdButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reward = adDef(ref.watch(tablesProvider), AdPlacement.bossSupport).reward;
    return AdButton(
      placement: AdPlacement.bossSupport,
      label: l10n.uiAdBossSupport(percentText(l10n, reward.number('damageBonus')), reward.integer('durationSec')),
    );
  }
}

/// 무료 소환: ‘무료 소환 · 남은 N회’ (하루 한도 − 오늘 본 횟수).
class FreeSummonAdButton extends ConsumerWidget {
  const FreeSummonAdButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = adDef(ref.watch(tablesProvider), AdPlacement.freeSummon).dailyLimit ?? 0;
    final used = ref.watch(gameStateProvider.select((s) => s.daily.ads[AdPlacement.freeSummon.name] ?? 0));
    if (!ref.watch(adOfferProvider(AdPlacement.freeSummon))) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AdButton(
        placement: AdPlacement.freeSummon,
        label: AppLocalizations.of(context).uiAdFreeSummon(limit - used),
      ),
    );
  }
}

/// 복귀 보상 ×2: 받은 금액(`lastOfflineGold`)만큼 한 번 더.
class OfflineAdButton extends ConsumerWidget {
  const OfflineAdButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = ref.watch(gameStateProvider.select((s) => s.lastOfflineGold));
    if (gold == null) return const SizedBox.shrink();
    return AdButton(placement: AdPlacement.offline, label: AppLocalizations.of(context).uiAdOffline(gold.format()));
  }
}

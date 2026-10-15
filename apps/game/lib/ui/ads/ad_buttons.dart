import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/pixel/pixel_icon_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
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
    // 좁으면 다음 줄로 (글자가 커진 실기기 폭에서도 넘치지 않게).
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        AdButton(
          placement: AdPlacement.chest,
          choice: 'gold',
          label: l10n.uiAdChestGold(base?.times(mult).format() ?? '', shortDecimal(mult)),
        ),
        AdButton(placement: AdPlacement.chest, choice: 'gems', label: l10n.uiAdChestGems(reward.integer('altGems'))),
      ],
    );
  }
}

/// 작은 광고 그림 버튼 (상단 바·줄 옆): 광고 그림 + 짧은 이득 숫자([short]), 전체 이득은 [label](낭독·길게 누르기).
/// 제안할 수 없으면(`adOfferProvider` false) 아무것도 그리지 않는다.
class AdIconButton extends ConsumerWidget {
  const AdIconButton({required this.placement, required this.label, required this.short, super.key});

  final AdPlacement placement;
  final String label;
  final String short;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adOfferProvider(placement))) return const SizedBox.shrink();
    return PixelIconButton(
      key: Key('ad.${placement.name}'),
      asset: UiSprites.ad,
      semanticLabel: label,
      onPressed: () => watchAd(ref, placement),
      trailing: Text(short),
    );
  }
}

/// 순풍: 광고 그림 + ‘×2’ (전체: ‘30분 ×2’).
class TailwindAdButton extends ConsumerWidget {
  const TailwindAdButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reward = adDef(ref.watch(tablesProvider), AdPlacement.tailwind).reward;
    final minutes = Duration(seconds: reward.integer('durationSec')).inMinutes;
    final mult = shortDecimal(reward.number('goldMultiplier'));
    return AdIconButton(
      placement: AdPlacement.tailwind,
      label: l10n.uiAdTailwind(minutes, mult),
      short: l10n.uiEffectMultiplier(mult),
    );
  }
}

/// 함포 지원 (보스 실패로 파밍 중일 때만): 광고 그림 + ‘+30%’ (전체: ‘피해 +30% · 30초’).
class BossSupportAdButton extends ConsumerWidget {
  const BossSupportAdButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farming = ref.watch(gameStateProvider.select((s) => s.progress.farming && !(s.battle?.bossActive ?? false)));
    if (!farming) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final reward = adDef(ref.watch(tablesProvider), AdPlacement.bossSupport).reward;
    final percent = percentText(l10n, reward.number('damageBonus'));
    return AdIconButton(
      placement: AdPlacement.bossSupport,
      label: l10n.uiAdBossSupport(percent, reward.integer('durationSec')),
      short: percent,
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

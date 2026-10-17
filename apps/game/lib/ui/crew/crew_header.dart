import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/collection_reward_row.dart';
import 'package:pirate_dot/ui/crew/fleet_swap_fx.dart';
import 'package:pirate_dot/ui/crew/merge_result.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/badge_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 선원 탭 머리 한 줄 (S1 실기기 ③ 2026-10-17 — 도감 상자·버튼이 화면을 다 써서 카드가 안 보였다):
/// [도감 13/40 · 공격력 +6% / 막대 · 다음 보너스(또는 금빛 보상 받기)] [자동 편성] [일괄 합치기 n명].
/// 다음 수집 보상 글은 도감 칸을 길게 누르면.
class CrewHeader extends ConsumerWidget {
  const CrewHeader({required this.mergeCount, super.key});

  /// 합칠 수 있는 선원 수(일괄 합치기 글).
  final int mergeCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    final total = t.crews.crews.length;
    final collected = ref.watch(gameStateProvider.select((s) => s.collection.length));
    final bonusOf = ref.watch(collectionBonusProvider);
    final bonus = ref.watch(
      gameStateProvider.select((s) {
        final b = bonusOf(s);
        if (b == null) return null;
        // 경제는 다음 보너스가 붙는 보유 수(nextAt)를 준다 → 남은 명 수. 다 모았으면(null) 0.
        final next = b.nextAt;
        return (b.attackBonus, next == null ? 0 : next - b.owned);
      }),
    );
    ref.watch(gameStateProvider.select((s) => s.progress.collectionClaimed.length));
    final s = ref.read(gameStateProvider);
    final ready = collectionRewards(s, t).where((r) => r.reached && !r.claimed).firstOrNull;
    final next = nextCollectReward(s, t);

    final collection = Tooltip(
      message: next == null ? l10n.uiCollectAllDone : l10n.uiCollectNext(next.at, collectRewardText(l10n, next)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(l10n.uiCrewCollection(collected, total), style: Skin.bold(16)),
                // 도감 보너스 (5명마다 공격력, 설계서 4.5).
                if (bonus case (final attack, _)) ...[
                  const SizedBox(width: 6),
                  Text(
                    l10n.uiCollectionBonus(percentText(l10n, attack)),
                    style: Skin.text(13, color: Skin.goldInk),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 받을 보상이 있으면 막대 자리에 금빛 [보상 받기].
          if (ready != null)
            TutorialSpot(
              id: 'collect.claim',
              child: SkinButton(
                key: const Key('collect.claim'),
                tone: SkinTone.gold,
                height: 40,
                onPressed: () => ref.read(commandSinkProvider).send(ClaimCollectionReward(ready.at)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l10n.uiCollectClaim(ready.at, collectRewardText(l10n, ready))),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: PixelBar(
                    key: const Key('crew.collectionBar'),
                    value: collected / total,
                    fill: Skin.goldBottom,
                    dots: 4,
                  ),
                ),
                if (bonus case (_, final nextIn) when nextIn > 0) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.uiCollectionNext(nextIn),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Skin.text(11, color: Skin.sub),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );

    Widget small(Widget child) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 104),
      child: child,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: Skin.inset(radius: Skin.radiusCard),
      child: Row(
        children: [
          Expanded(child: collection),
          const SizedBox(width: 6),
          // 수동 편성이 기본, 한 번에 채우기 (사용자 결정).
          small(
            SkinButton(
              key: const Key('fleet.auto'),
              height: 44,
              onPressed: () => autoFleetWithFeedback(context, ref),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.uiFleetAuto)),
            ),
          ),
          const SizedBox(width: 6),
          small(
            TutorialSpot(
              id: 'crew.mergeAll',
              child: PixelDot(
                dotKey: const Key('crew.mergeAll.dot'),
                show: ref.watch(mergeBadgeProvider),
                child: SkinButton(
                  key: const Key('crew.mergeAll'),
                  tone: SkinTone.gold,
                  height: 44,
                  onPressed: () => mergeAllWithResult(context, ref),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mergeCount > 0 ? l10n.uiCrewMergeAllCount(mergeCount) : l10n.uiCrewMergeAll),
                        if (mergeCount > 0) const Icon(Icons.arrow_upward_rounded, size: 18, color: Skin.mintInk),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

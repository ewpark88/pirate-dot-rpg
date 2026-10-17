import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 전장 아래 ‘다음 목표’ 도트 띠 (설계서 4.5, 4.12 목표 막대). 목표가 없으면 아무것도 그리지 않는다.
class GoalBar extends ConsumerWidget {
  const GoalBar({this.compact = false, super.key});

  /// 진행 게이지 안 얇은 한 줄 (S1 지시 2026-10-15: 전장 위 UI 높이 절반 이하) — 카드 없이 흰 글자.
  final bool compact;

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

    if (compact) {
      return TutorialSpot(
        id: 'goal',
        child: Row(
          key: const Key('goal'),
          children: [
            const SkinIcon(UiSprites.flag, size: 13),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Skin.outlined(12),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 44,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: progress, color: Skin.goldTop, backgroundColor: Colors.white24),
              ),
            ),
          ],
        ),
      );
    }

    final u = pixelUnit(context);
    // 전장 바로 아래 크림색 알약 (스킨 r1): 깃발 · 문구 · 진행 막대.
    return TutorialSpot(
      id: 'goal',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
        child: DecoratedBox(
          key: const Key('goal'),
          decoration: BoxDecoration(
            color: Skin.cream,
            borderRadius: BorderRadius.circular(18),
            boxShadow: Skin.shadowSmall,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: u * 2),
            child: Row(
              children: [
                const PixelSprite(UiSprites.flag, dots: 16, scale: 1),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: PixelBar(value: progress, fill: Skin.goldBottom),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

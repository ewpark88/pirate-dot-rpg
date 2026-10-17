import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

/// 선원 상세 '레벨을 올리는 이유'(사용자 피드백 #12): 레벨업하면 공격력 +x%(초당 a → b) · 지금 합치면 Lv a → b(56dp 합치기 버튼,
/// 피드백 #16) 또는 다음 레벨까지 일반 카드 n장 · 승급까지 Lv n(승급하면 공격력 +y%). 값은 모두 경제 crewGrowth.
class CrewGrowthReasons extends ConsumerWidget {
  const CrewGrowthReasons({required this.crewId, super.key});

  final String crewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    final level = ref.watch(gameStateProvider.select((s) => s.crews[crewId]?.level));
    final g = ref.watch(gameStateProvider.select((s) => crewGrowth(s, tables, crewId)));
    if (g == null || level == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    Widget line(Key key, IconData icon, String text, {Color color = Skin.ink}) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              key: key,
              style: Skin.text(15, color: color),
            ),
          ),
        ],
      ),
    );
    return Container(
      key: const Key('crew.detail.why'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Skin.mint, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (g.levelGain > 0)
            line(
              const Key('crew.detail.why.level'),
              Icons.trending_up_rounded,
              l10n.uiCrewWhyLevel(percentText(l10n, g.levelGain), g.dpsNow.format(), g.dpsNext.format()),
              color: Skin.mintInk,
            ),
          if (g.cardsToLevel > 0)
            line(const Key('crew.detail.why.cards'), Icons.style_rounded, l10n.uiCrewCardsToLevel(g.cardsToLevel)),
          if (g.levelsToPromote case final n?)
            line(
              const Key('crew.detail.why.promote'),
              Icons.workspace_premium_rounded,
              n > 0
                  ? l10n.uiCrewPromoteIn(n, percentText(l10n, g.promoteGain))
                  : l10n.uiCrewPromoteGain(percentText(l10n, g.promoteGain)),
              color: Skin.goldInk,
            ),
          if (g.mergeLevels > 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SkinButton(
                key: Key('crew.detail.merge.$crewId'),
                tone: SkinTone.gold,
                height: 56,
                onPressed: () => ref.read(commandSinkProvider).send(const MergeAllCards()),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l10n.uiCrewMergeNow(level, level + g.mergeLevels), style: Skin.text(18)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

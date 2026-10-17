import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 도감 수집 보상 (S1 2026-10-17 '수집의 재미', 경제 S2 collectionRewards): 선원 탭 도감 카드 아래 한 줄 —
// 받을 칸이 있으면 반짝이는 금빛 [보상 받기 (n명)](→ ClaimCollectionReward, 보상 터짐은 RewardGate), 없으면 '다음 보상 n명: …'.

/// 보상 한 칸의 글 ('젬 30' · '무료 소환 1회' · 둘 다면 ' + ').
String collectRewardText(AppLocalizations l, CollectionRewardView r) => [
  if (r.gems > 0) l.uiCollectGems(r.gems),
  if (r.summons > 0) l.uiCollectSummons(r.summons),
].join(' + ');

/// 다음에 닿을(아직 못 닿은) 칸. 다 닿았으면 null.
CollectionRewardView? nextCollectReward(GameState s, GameTables t) =>
    collectionRewards(s, t).where((r) => !r.reached).firstOrNull;

class CollectionRewardRow extends ConsumerWidget {
  const CollectionRewardRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    // 보유 수·받은 칸이 바뀔 때만 다시 짓는다.
    ref.watch(gameStateProvider.select((s) => '${s.collection.length}|${s.progress.collectionClaimed.join(',')}'));
    final s = ref.read(gameStateProvider);
    final ready = collectionRewards(s, t).where((r) => r.reached && !r.claimed).firstOrNull;
    if (ready != null) {
      return SkinButton(
        key: const Key('collect.claim'),
        tone: SkinTone.gold,
        onPressed: () => ref.read(commandSinkProvider).send(ClaimCollectionReward(ready.at)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('${l10n.uiCollectClaim(ready.at)} · ${collectRewardText(l10n, ready)}'),
        ),
      );
    }
    final next = nextCollectReward(s, t);
    return Text(
      next == null ? l10n.uiCollectAllDone : l10n.uiCollectNext(next.at, collectRewardText(l10n, next)),
      key: const Key('collect.next'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Skin.text(14, color: Skin.sub),
    );
  }
}

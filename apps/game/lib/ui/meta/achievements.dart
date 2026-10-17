import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart' show TutorialSpot;

// 업적 (S1 2026-10-18 업적·칭호 정리 — 계약 요청 docs/contracts/requests/ui-achievements.md, S2 구현 전):
// 항해 탭 칭호 띠 옆 '업적' 버튼(받을 것 빨간 점) → 시트: 아이콘 · 이름 · 단계 별 · 진행 막대(값/다음 목표) · [받기 +n젬] / 완료.
// 값·단계·받기는 경제(achievementsView · ClaimAchievement), 받은 순간 보상 터짐은 RewardGate(AchievementClaimed).

/// 업적 목록(경제 achievementsView — S5 0dd77773).
final achievementsProvider = Provider<List<AchievementView>>((ref) {
  final t = ref.watch(tablesProvider);
  return achievementsView(ref.watch(gameStateProvider), t);
});

/// 받을 수 있는 업적 수(빨간 점).
final achievementsClaimableProvider = Provider<int>((ref) {
  final t = ref.watch(tablesProvider);
  return ref.watch(gameStateProvider.select((s) => achievementsClaimable(s, t)));
});

/// 업적 이름(표 nameKey = platformAch*).
String achievementName(AppLocalizations l, String nameKey) => switch (nameKey) {
  'platformAchKills' => l.platformAchKills,
  'platformAchBosses' => l.platformAchBosses,
  'platformAchStage' => l.platformAchStage,
  'platformAchRebirths' => l.platformAchRebirths,
  'platformAchCollection' => l.platformAchCollection,
  'platformAchMythic' => l.platformAchMythic,
  'platformAchTower' => l.platformAchTower,
  'platformAchRushClear' => l.platformAchRushClear,
  'platformAchRushFast' => l.platformAchRushFast,
  'platformAchFever' => l.platformAchFever,
  'platformAchUltimate' => l.platformAchUltimate,
  'platformAchDungeon' => l.platformAchDungeon,
  'platformAchBounty' => l.platformAchBounty,
  'platformAchSummons' => l.platformAchSummons,
  _ => l.platformAchShipLevel,
};

/// 표 iconKey → 화면 아이콘.
String achievementIcon(String key) => switch (key) {
  'sword' => UiSprites.tabCrew,
  'flag' || 'skull' || 'target' => UiSprites.flag,
  'rebirth' => UiSprites.rebirth,
  'book' => UiSprites.book,
  'star' || 'fire' => UiSprites.star,
  'trophy' || 'crown' => UiSprites.trophy,
  'clock' || 'bolt' => UiSprites.tailwind,
  'gate' => UiSprites.tabMap,
  'chest' => UiSprites.chest,
  _ => UiSprites.coin,
};

/// 항해 탭 '업적' 버튼(칭호 띠 옆).
class AchievementsButton extends ConsumerWidget {
  const AchievementsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(achievementsClaimableProvider);
    return TutorialSpot(
      id: 'ach.open',
      child: PixelDot(
        dotKey: const Key('ach.dot'),
        show: n > 0,
        count: n,
        // 작은 알약(칭호 띠 옆 한 줄) — 누르는 칸은 48dp.
        child: Semantics(
          button: true,
          label: AppLocalizations.of(context).uiAchTitle,
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('ach.open'),
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                unawaited(showPixelSheet<void>(context, maxHeight: 0.85, builder: (_) => const AchievementsSheet())),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Skin.cream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Skin.outline, width: Skin.outlineWidth),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SkinIcon(UiSprites.trophy, size: 20),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context).uiAchTitle, style: Skin.bold(13)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AchievementsSheet extends ConsumerWidget {
  const AchievementsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(achievementsProvider);
    return Column(
      key: const Key('ach.sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubRibbon(l10n.uiAchTitle),
        const SizedBox(height: 8),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [for (final a in list) _Row(a: a)],
          ),
        ),
      ],
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.a});

  final AchievementView a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final target = a.nextTarget;
    return Container(
      key: Key('ach.${a.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: Skin.inset(radius: 14),
      child: Row(
        children: [
          IconCell(color: partCellColors[0], size: 48, child: SkinIcon(achievementIcon(a.iconKey), size: 32)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(achievementName(l10n, a.nameKey), style: Skin.bold(15))),
                    const SizedBox(width: 6),
                    // 단계 별(받은 단계 금빛).
                    for (var i = 0; i < a.steps; i++)
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: i < a.step ? const Color(0xFFFFC53D) : Skin.plainEdge,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (target != null) ...[
                  // 짧을수록 좋은 기록(러시 최고 초)은 '목표 n초 이하'로, 기록이 없으면 0.
                  SkinBar(
                    value: a.lowerIsBetter
                        ? (a.value == 0 ? 0 : (target / a.value).clamp(0, 1).toDouble())
                        : (a.value / target).clamp(0, 1).toDouble(),
                    color: Skin.goldTop,
                    height: 8,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.lowerIsBetter
                        ? (a.value == 0 ? l10n.uiAchNoRecord(target) : l10n.uiAchFast(a.value.toString(), target))
                        : l10n.uiAchProgress(BigNum.from(a.value).format(), BigNum.from(target).format()),
                    style: Skin.text(12, color: Skin.sub),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (target == null)
            Text(l10n.uiAchDone, style: Skin.bold(14, color: Skin.mintInk))
          else
            SkinButton(
              key: Key('ach.claim.${a.id}'),
              tone: a.claimable ? SkinTone.gold : SkinTone.plain,
              height: 44,
              onPressed: a.claimable ? () => ref.read(commandSinkProvider).send(ClaimAchievement(a.id)) : null,
              child: Text(l10n.uiAchClaim(a.nextGems ?? 0)),
            ),
        ],
      ),
    );
  }
}

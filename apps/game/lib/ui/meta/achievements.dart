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

// 업적 (S1 2026-10-18 업적·칭호 정리 — 계약 요청 docs/contracts/requests/ui-achievements.md, S2 구현 전):
// 항해 탭 칭호 띠 옆 '업적' 버튼(받을 것 빨간 점) → 시트: 아이콘 · 이름 · 단계 별 · 진행 막대(값/다음 목표) · [받기 +n젬] / 완료.
// 지금은 임시 어댑터 — 세이브에서 셀 수 있는 것만(최고 스테이지·환생·도감·탑 층·배 부위 레벨 합), 받은 단계는 0.

/// 업적 한 줄(경제 achievementsView와 같은 모양으로 맞출 예정).
typedef AchievementView = ({
  String id,
  String icon,
  int value,
  int step,
  int steps,
  int? nextTarget,
  int? nextGems,
  bool claimable,
});

/// 임시 표: id → (아이콘, [(목표, 젬)]).
const _fake = <String, (String, List<(int, int)>)>{
  'stage': (UiSprites.flag, [(20, 10), (40, 20), (80, 40), (150, 80), (300, 150)]),
  'rebirths': (UiSprites.rebirth, [(1, 20), (3, 40), (5, 60), (10, 100), (20, 200)]),
  'collection': (UiSprites.book, [(10, 20), (20, 40), (30, 80), (40, 150)]),
  'tower': (UiSprites.trophy, [(10, 20), (20, 40), (30, 80), (50, 150)]),
  'shipLevel': (UiSprites.coin, [(100, 10), (500, 40), (2000, 100)]),
};

int _valueOf(GameState s, String id) => switch (id) {
  'stage' => s.progress.bestStage,
  'rebirths' => s.progress.rebirths,
  'collection' => s.collection.length,
  'tower' => s.tower?.best ?? 0,
  _ => s.ship.parts.values.fold(0, (a, b) => a + b),
};

/// 업적 목록(계약 오면 경제 achievementsView로 바꾼다).
final achievementsProvider = Provider<List<AchievementView>>((ref) {
  final s = ref.watch(gameStateProvider);
  return [
    for (final MapEntry(key: id, value: (icon, steps)) in _fake.entries)
      () {
        final value = _valueOf(s, id);
        const step = 0; // 받은 단계 — 세이브 achievements(계약) 전엔 0
        final next = step < steps.length ? steps[step] : null;
        return (
          id: id,
          icon: icon,
          value: value,
          step: step,
          steps: steps.length,
          nextTarget: next?.$1,
          nextGems: next?.$2,
          claimable: next != null && value >= next.$1,
        );
      }(),
  ];
});

/// 받을 수 있는 업적 수(빨간 점).
final achievementsClaimableProvider = Provider<int>(
  (ref) => ref.watch(achievementsProvider).where((a) => a.claimable).length,
);

/// 받기(계약 ClaimAchievement 자리 — 지금은 아무것도 안 함).
final achievementClaimProvider = Provider<void Function(String id)>((_) => (_) {});

String achievementName(AppLocalizations l, String id) => switch (id) {
  'stage' => l.uiAchStage,
  'rebirths' => l.uiAchRebirths,
  'collection' => l.uiAchCollection,
  'tower' => l.uiAchTower,
  'shipLevel' => l.uiAchShipLevel,
  'kills' => l.uiAchKills,
  _ => l.uiAchBosses,
};

/// 항해 탭 '업적' 버튼(칭호 띠 옆).
class AchievementsButton extends ConsumerWidget {
  const AchievementsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(achievementsClaimableProvider);
    return PixelDot(
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
          IconCell(color: partCellColors[0], size: 48, child: SkinIcon(a.icon, size: 32)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(achievementName(l10n, a.id), style: Skin.bold(15))),
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
                  SkinBar(value: (a.value / target).clamp(0, 1).toDouble(), color: Skin.goldTop, height: 8),
                  const SizedBox(height: 2),
                  Text(
                    l10n.uiAchProgress(BigNum.from(a.value).format(), BigNum.from(target).format()),
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
              onPressed: a.claimable ? () => ref.read(achievementClaimProvider)(a.id) : null,
              child: Text(l10n.uiAchClaim(a.nextGems ?? 0)),
            ),
        ],
      ),
    );
  }
}

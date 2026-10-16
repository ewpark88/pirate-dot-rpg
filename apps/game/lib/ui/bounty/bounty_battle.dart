import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart' show RecordedTick;
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart';
import 'package:pirate_dot/ui/bounty/bounty_vm.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/reward_sparkle.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

// 현상금 전투 중 UI (기획 6절 ③④): 위쪽 '현상금' 띠, 후퇴 버튼(보스 도전 자리), 끝나면 결과 작은 창.

/// 전장 위 '현상금 · 보스 n단계' 띠 (현상금 전투 중일 때만, 누름 통과).
class BountyStrip extends ConsumerWidget {
  const BountyStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(bountyProvider.select((v) => v.active));
    if (active == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      child: Container(
        key: const Key('bounty.strip'),
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.fromLTRB(6, 3, 12, 3),
        decoration: BoxDecoration(
          color: const Color(0xFF7A3E17).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Skin.goldBottom, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SkinIcon(UiSprites.flag),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                l10n.uiBountyStrip(bossName(l10n, ref, active.bossId), active.tier),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Skin.text(13, color: const Color(0xFFFFE27A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 후퇴 버튼 (선원 줄 오른쪽, 궁극기 옆 = 보스 도전 자리) → RetreatBounty. 현상금 전투 중에만.
class BountyRetreatButton extends ConsumerWidget {
  const BountyRetreatButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(bountyProvider.select((v) => v.active != null));
    if (!active) return const SizedBox.shrink();
    return FittedBox(
      child: SkinButton(
        key: const Key('bounty.retreat'),
        tone: SkinTone.plain,
        onPressed: ref.read(bountyCommandsProvider).retreat,
        child: Text(AppLocalizations.of(context).uiBountyRetreat),
      ),
    );
  }
}

/// 결과 작은 창: 성공 = 보상(반짝임) / 실패 = '티켓은 돌려받았어요 · 피해 n%' (이유와 상관없이).
class BountyResultGate extends ConsumerStatefulWidget {
  const BountyResultGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BountyResultGate> createState() => _BountyResultGateState();
}

class _BountyResultGateState extends ConsumerState<BountyResultGate> {
  StreamSubscription<RecordedTick>? _sub;

  @override
  void initState() {
    super.initState();
    // 결과 이벤트(BountyCleared·BountyFailed·BountySwept) → 결과 → 작은 창 한 번.
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      tick.events.forEach(ref.read(bountyResultProvider.notifier).onEvent);
    });
    ref.listenManual(bountyResultProvider, (_, result) {
      if (result == null || !mounted) return;
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => _ResultDialog(result: result),
        ).whenComplete(() => ref.read(bountyResultProvider.notifier).ack()),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ResultDialog extends ConsumerWidget {
  const _ResultDialog({required this.result});

  final BountyResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PixelDialog(
      key: Key(result.success ? 'bounty.result.clear' : 'bounty.result.fail'),
      icon: BossPortrait(bossId: result.bossId, size: 64, dim: !result.success),
      title: result.success ? l10n.uiBountyClear : bossName(l10n, ref, result.bossId),
      content: result.success
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkinIcon(rewardIcon(result.reward), size: 28),
                const SizedBox(width: 6),
                RewardSparkle(
                  child: Text(
                    rewardText(l10n, result.reward, result.amount),
                    style: Skin.text(24, color: Skin.primaryEdge),
                  ),
                ),
              ],
            )
          : Text(
              l10n.uiBountyFail((result.damage * 100).round()),
              textAlign: TextAlign.center,
              style: Skin.text(16),
            ),
      actions: [
        SkinButton(
          key: const Key('bounty.result.ok'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.uiOk),
        ),
      ],
    );
  }
}

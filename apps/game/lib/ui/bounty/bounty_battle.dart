import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart' show RecordedTick;
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart';
import 'package:pirate_dot/ui/bounty/bounty_vm.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/reward_sparkle.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

// 현상금 전투 중 UI (기획 6절 ③④): 위쪽 '현상금' 글(떠 있는 띠 안 — SceneStrip), 후퇴 버튼(보스 도전 자리), 끝나면 결과 작은 창.

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
        showSkinDialog<void>(
          context,
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
                  child: OutlineText(rewardText(l10n, result.reward, result.amount), size: 24, tone: OutlineTone.gold),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart' show RecordedTick;
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart';
import 'package:pirate_dot/ui/bounty/bounty_vm.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/scene/scene_result.dart';

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

/// 현상금 결과(HD 결 — 탑·러시와 같은 결과 창): 성공 = 보상 수 굴림 → [확인]에 위 막대로 비행, 실패 = 입힌 피해 % 굴림 +
/// '아깝다! 다음엔 약점 편성'.
class _ResultDialog extends ConsumerWidget {
  const _ResultDialog({required this.result});

  final BountyResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final r = result;
    return SceneResultDialog(
      key: Key(r.success ? 'bounty.result.clear' : 'bounty.result.fail'),
      icon: BossPortrait(bossId: r.bossId, size: 64, dim: !r.success),
      title: r.success ? l10n.uiBountyClear : bossName(l10n, ref, r.bossId),
      big: r.success ? null : (value: (r.damage * 100).round(), text: (v) => '$v%'),
      lines: [if (!r.success) l10n.uiBountyFail((r.damage * 100).round())],
      rewards: [if (r.success) (icon: rewardIcon(r.reward), text: rewardText(l10n, r.reward, r.amount))],
      failed: !r.success,
      okKey: const Key('bounty.result.ok'),
    );
  }
}

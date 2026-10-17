import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/scene/scene_vm.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/reward_sparkle.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 탑·러시 전투 중 UI (S5 계약): 위쪽 띠('심연 12층 · 2/3파' / '보스 3/5 · 1:42'), 후퇴(보스 도전 자리), 끝나면 결과 창,
// 소탕은 토스트. 시작하면 시트를 닫는다(전장이 보이게).

/// 전장 위 장면 띠 (탑·러시 중일 때만, 누름 통과). 현상금 띠와 같은 모양, 심연 보라.
class SceneStrip extends ConsumerWidget {
  const SceneStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tower, rush) = ref.watch(gameStateProvider.select((s) => (s.battle?.tower, s.battle?.rush)));
    if (tower == null && rush == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final tickMs = ref.watch(tablesProvider).waves.tickMs;
    final text = tower != null
        ? l10n.uiTowerStrip(tower.floor, tower.wave + 1, tower.waves)
        : l10n.uiRushStrip(rush!.index + 1, rush.total, sceneClock(l10n, rush.ticks, tickMs));
    return IgnorePointer(
      child: Container(
        key: Key(tower != null ? 'tower.strip' : 'rush.strip'),
        padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2E2260).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB79CFF), width: 1.5),
        ),
        child: OutlineText(text, size: 15),
      ),
    );
  }
}

/// 후퇴 (보스 도전 자리) → RetreatTower / RetreatRush. 도달 층·잡은 보스까지는 기록된다.
class SceneRetreatButton extends ConsumerWidget {
  const SceneRetreatButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tower, rush) = ref.watch(
      gameStateProvider.select((s) => (s.battle?.tower != null, s.battle?.rush != null)),
    );
    if (!tower && !rush) return const SizedBox.shrink();
    return FittedBox(
      child: SkinButton(
        key: const Key('scene.retreat'),
        tone: SkinTone.plain,
        onPressed: () => ref.read(commandSinkProvider).send(tower ? const RetreatTower() : const RetreatRush()),
        child: Text(AppLocalizations.of(context).uiBountyRetreat),
      ),
    );
  }
}

/// 탑·러시 이벤트 → 시작이면 시트 닫기, 끝이면 결과 창 한 번, 소탕이면 토스트.
class SceneGate extends ConsumerStatefulWidget {
  const SceneGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SceneGate> createState() => _SceneGateState();
}

class _SceneGateState extends ConsumerState<SceneGate> {
  StreamSubscription<RecordedTick>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) => tick.events.forEach(_on));
  }

  void _on(GameEvent e) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    switch (e) {
      case TowerStarted() || RushStarted():
        ref.read(dockTabRequestProvider.notifier).close();
      case TowerSwept(:final floor, :final chestGems, :final chestCards):
        showSkinToast(
          context,
          l10n.uiTowerSwept(floor, sceneReward(l10n, gems: chestGems, cards: chestCards)),
        );
      case TowerEnded():
        unawaited(showSkinDialog<void>(context, builder: (_) => TowerResultDialog(end: e)));
      case RushEnded():
        unawaited(showSkinDialog<void>(context, builder: (_) => RushResultDialog(end: e)));
      default:
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 탑 결과: 'n층까지!' · 끝난 이유 · 처치 수 · 상자(반짝임).
class TowerResultDialog extends StatelessWidget {
  const TowerResultDialog({required this.end, super.key});

  final TowerEnded end;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final why = switch (end.reason) {
      'retreat' => l10n.uiTowerEndRetreat,
      'interrupted' => l10n.uiTowerEndInterrupted,
      'timeout' => l10n.uiTowerEndTimeout(end.floor),
      _ => l10n.uiTowerEndSunk,
    };
    return _ResultDialog(
      key: const Key('tower.result'),
      title: l10n.uiTowerReached(end.floor),
      lines: [why, l10n.uiSceneKills(end.kills)],
      reward: sceneReward(l10n, gems: end.chestGems, cards: end.chestCards),
    );
  }
}

/// 러시 결과: 다 잡았으면 '5마리 모두! m:ss'(+ 새 기록), 아니면 'n/5 처치' · 보상.
class RushResultDialog extends ConsumerWidget {
  const RushResultDialog({required this.end, super.key});

  final RushEnded end;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    final total = t.meta.raw.obj('rush').strs('lineup').length;
    final time = sceneClock(l10n, end.ticks, t.waves.tickMs);
    return _ResultDialog(
      key: const Key('rush.result'),
      title: end.reason == 'cleared' ? l10n.uiRushCleared(time) : l10n.uiRushPartial(end.killed, total),
      lines: [if (end.best) l10n.uiRushNewBest],
      reward: sceneReward(l10n, gems: end.gems, pieces: end.pieces),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.title, required this.lines, required this.reward, super.key});

  final String title;
  final List<String> lines;
  final String reward;

  @override
  Widget build(BuildContext context) => PixelDialog(
    title: title,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines) Text(line, textAlign: TextAlign.center, style: Skin.text(16)),
        if (reward.isNotEmpty) ...[
          const SizedBox(height: 10),
          RewardSparkle(child: OutlineText(reward, size: 22, tone: OutlineTone.gold, fit: true)),
        ],
      ],
    ),
    actions: [
      SkinButton(
        key: const Key('scene.result.ok'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(AppLocalizations.of(context).uiOk),
      ),
    ],
  );
}

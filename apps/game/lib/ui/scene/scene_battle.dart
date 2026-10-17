import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart' show bossName;
import 'package:pirate_dot/ui/bounty/bounty_vm.dart';
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

/// 장면 글 — 떠 있는 띠 안 스테이지 글자 자리(사용자 2026-10-18 '띠 아래 안내 줄이 보스를 가린다'): 탑·러시·던전·현상금 중에만.
/// '심연 12층 · 2/3파' · '보스 3/5 · 1:42' · '요일 던전 3단계 · 1/2파' · '현상금 · 보스 2단계'.
class SceneStrip extends ConsumerWidget {
  const SceneStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tower, rush, dungeon) = ref.watch(
      gameStateProvider.select((s) => (s.battle?.tower, s.battle?.rush, s.battle?.dungeon)),
    );
    final bounty = ref.watch(bountyProvider.select((v) => v.active));
    final l10n = AppLocalizations.of(context);
    final tickMs = ref.watch(tablesProvider).waves.tickMs;
    final text = switch ((tower, rush, dungeon)) {
      (final w?, _, _) => l10n.uiTowerStrip(w.floor, w.wave + 1, w.waves),
      (_, final r?, _) => l10n.uiRushStrip(r.index + 1, r.total, sceneClock(l10n, r.ticks, tickMs)),
      (_, _, final d?) => l10n.uiDungeonStrip(d.step, d.wave + 1, d.waves),
      _ => bounty == null ? '' : l10n.uiBountyStrip(bossName(l10n, ref, bounty.bossId), bounty.tier),
    };
    final key = switch ((tower, rush, dungeon)) {
      (_?, _, _) => 'tower.strip',
      (_, _?, _) => 'rush.strip',
      (_, _, _?) => 'dungeon.strip',
      _ => 'bounty.strip',
    };
    return Text(
      text,
      key: Key(key),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Skin.outlined(14, color: const Color(0xFFFFE27A)),
    );
  }
}

/// 후퇴 — 떠 있는 띠 안 장면 글 옆 작은 버튼(사용자 2026-10-18 '후퇴가 내 배 체력바를 가린다'): 현상금 RetreatBounty ·
/// 탑 RetreatTower · 러시 RetreatRush · 던전 RetreatDungeon. 도달 층·잡은 보스까지는 기록된다.
class SceneRetreatButton extends ConsumerWidget {
  const SceneRetreatButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tower, rush, dungeon) = ref.watch(
      gameStateProvider.select((s) => (s.battle?.tower != null, s.battle?.rush != null, s.battle?.dungeon != null)),
    );
    final bounty = ref.watch(bountyProvider.select((v) => v.active != null));
    if (!tower && !rush && !dungeon && !bounty) return const SizedBox.shrink();
    final cmd = switch ((tower, rush, dungeon)) {
      (true, _, _) => const RetreatTower(),
      (_, true, _) => const RetreatRush(),
      (_, _, true) => const RetreatDungeon(),
      _ => const RetreatBounty(),
    };
    final label = AppLocalizations.of(context).uiBountyRetreat;
    // 작은 알약(글 크기만큼) — 띠 한 줄 안에 들어가게. 누르는 자리는 위아래로 넉넉히(띠 높이).
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('scene.retreat'),
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(commandSinkProvider).send(cmd),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 0, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Skin.cream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Skin.outline, width: 1.5),
            ),
            child: Text(label, style: Skin.bold(12)),
          ),
        ),
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
      case TowerStarted() || RushStarted() || DungeonStarted():
        ref.read(dockTabRequestProvider.notifier).close();
      case TowerSwept(:final floor, :final chestGems, :final chestCards):
        showSkinToast(
          context,
          l10n.uiTowerSwept(floor, sceneReward(l10n, gems: chestGems, cards: chestCards)),
        );
      case DungeonCleared(swept: true, :final step, :final gems, :final cards):
        showSkinToast(context, l10n.uiDungeonSwept(step, sceneReward(l10n, gems: gems, cards: cards.length)));
      case DungeonCleared(:final step, :final gems, :final cards):
        unawaited(
          showSkinDialog<void>(
            context,
            builder: (_) => _ResultDialog(
              key: const Key('dungeon.result'),
              title: l10n.uiDungeonClear(step),
              lines: const [],
              reward: sceneReward(l10n, gems: gems, cards: cards.length),
            ),
          ),
        );
      case DungeonFailed(:final step, :final reason):
        unawaited(
          showSkinDialog<void>(
            context,
            builder: (_) => _ResultDialog(
              key: const Key('dungeon.fail'),
              title: l10n.uiDungeonFail(step),
              lines: [
                switch (reason) {
                  'retreat' => l10n.uiTowerEndRetreat,
                  'timeout' => l10n.uiDungeonTimeout,
                  'interrupted' => l10n.uiTowerEndInterrupted,
                  _ => l10n.uiTowerEndSunk,
                },
                l10n.uiDungeonTicketBack,
              ],
              reward: '',
            ),
          ),
        );
      // 아무것도 못 했으면(앱이 꺼져 0층·0마리로 끝남) 빈 결과 창을 띄우지 않는다(S1 실기기 '0/5 처치' 빈 창).
      case TowerEnded(floor: 0, chestGems: 0, chestCards: 0):
      case RushEnded(killed: 0, gems: 0, pieces: 0):
        break;
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
      lines: [
        if (end.best) l10n.uiRushNewBest,
        switch (end.reason) {
          'cleared' => '',
          'retreat' => l10n.uiTowerEndRetreat,
          'interrupted' => l10n.uiTowerEndInterrupted,
          'timeout' => l10n.uiDungeonTimeout,
          _ => l10n.uiTowerEndSunk,
        },
      ].where((t) => t.isNotEmpty).toList(),
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

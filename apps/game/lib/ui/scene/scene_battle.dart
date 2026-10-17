import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart' show bossName;
import 'package:pirate_dot/ui/bounty/bounty_vm.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/scene/scene_result.dart';
import 'package:pirate_dot/ui/scene/scene_vm.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
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

  /// 끝나기 전 최고 기록(이벤트가 올 때 상태는 이미 새 기록이라 — 신기록 도장·이전 기록 줄 긋기용).
  late int _towerBest = ref.read(gameStateProvider).tower?.best ?? 0;
  late int? _rushBest = ref.read(gameStateProvider).rush?.bestTicks;
  late Map<String, int> _dungeonBest = {...?ref.read(gameStateProvider).dungeon?.cleared};

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) => tick.events.forEach(_on));
  }

  void _show(Widget dialog) => unawaited(showSkinDialog<void>(context, builder: (_) => dialog));

  void _on(GameEvent e) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    switch (e) {
      case TowerStarted() || RushStarted() || DungeonStarted():
        ref.read(dockTabRequestProvider.notifier).close();
      // 탑·던전 소탕은 보상 터짐(RewardGate)이 보여 준다(모든 받기 같은 연출 — S1 2026-10-18).
      case TowerSwept() || DungeonCleared(swept: true):
        break;
      case DungeonCleared(:final group, :final step, :final gems, :final cards):
        final prev = _dungeonBest[group] ?? 0;
        _dungeonBest = {..._dungeonBest, group: math.max(prev, step)};
        _show(
          SceneResultDialog(
            key: const Key('dungeon.result'),
            title: l10n.uiDungeonClear(step),
            big: (value: step, text: l10n.uiDungeonStepBig),
            record: step > prev,
            previous: prev > 0 ? l10n.uiPrevRecord(l10n.uiDungeonStepBig(prev)) : null,
            rewards: sceneRewardItems(l10n, gems: gems, cards: cards.length),
          ),
        );
      case DungeonFailed(:final step, :final reason):
        _show(
          SceneResultDialog(
            key: const Key('dungeon.fail'),
            title: l10n.uiDungeonFail(step),
            big: null,
            failed: reason == 'sunk' || reason == 'timeout',
            lines: [
              switch (reason) {
                'retreat' => l10n.uiTowerEndRetreat,
                'timeout' => l10n.uiDungeonTimeout,
                'interrupted' => l10n.uiTowerEndInterrupted,
                _ => l10n.uiTowerEndSunk,
              },
              l10n.uiDungeonTicketBack,
            ],
          ),
        );
      // 아무것도 못 했으면(앱이 꺼져 0층·0마리로 끝남) 빈 결과 창을 띄우지 않는다(S1 실기기 '0/5 처치' 빈 창).
      case TowerEnded(floor: 0, chestGems: 0, chestCards: 0):
      case RushEnded(killed: 0, gems: 0, pieces: 0):
        break;
      case TowerEnded():
        _show(TowerResultDialog(end: e, previousBest: _towerBest));
        _towerBest = math.max(_towerBest, e.floor);
      case RushEnded():
        _show(RushResultDialog(end: e, previousTicks: _rushBest));
        if (e.best) _rushBest = e.ticks;
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

/// 탑 결과: 도달 층 굴림(신기록이면 도장·이전 기록 줄 긋기) · 끝난 이유 · 처치 수 · 상자. 가라앉음·시간 초과는 약점 편성 바로가기.
class TowerResultDialog extends StatelessWidget {
  const TowerResultDialog({required this.end, this.previousBest = 0, super.key});

  final TowerEnded end;

  /// 이번 탑 전 최고 층.
  final int previousBest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final why = switch (end.reason) {
      'retreat' => l10n.uiTowerEndRetreat,
      'interrupted' => l10n.uiTowerEndInterrupted,
      'timeout' => l10n.uiTowerEndTimeout(end.floor),
      _ => l10n.uiTowerEndSunk,
    };
    return SceneResultDialog(
      key: const Key('tower.result'),
      title: l10n.uiTowerReached(end.floor),
      big: (value: end.floor, text: l10n.uiTowerFloorBig),
      record: end.floor > previousBest,
      previous: previousBest > 0 ? l10n.uiPrevRecord(l10n.uiTowerFloorBig(previousBest)) : null,
      lines: [why, l10n.uiSceneKills(end.kills)],
      rewards: sceneRewardItems(l10n, gems: end.chestGems, cards: end.chestCards),
      failed: end.reason == 'sunk' || end.reason == 'timeout',
    );
  }
}

/// 러시 결과: 다 잡았으면 걸린 시간 굴림(+ 새 기록 도장·이전 기록), 아니면 처치 수 · 보상.
class RushResultDialog extends ConsumerWidget {
  const RushResultDialog({required this.end, this.previousTicks, super.key});

  final RushEnded end;

  /// 이번 러시 전 최고 기록(틱).
  final int? previousTicks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    final total = t.meta.raw.obj('rush').strs('lineup').length;
    final cleared = end.reason == 'cleared';
    final prev = previousTicks;
    return SceneResultDialog(
      key: const Key('rush.result'),
      title: cleared
          ? l10n.uiRushCleared(sceneClock(l10n, end.ticks, t.waves.tickMs))
          : l10n.uiRushPartial(end.killed, total),
      big: cleared
          ? (value: end.ticks, text: (v) => sceneClock(l10n, v, t.waves.tickMs))
          : (value: end.killed, text: (v) => '$v / $total'),
      record: end.best,
      previous: prev != null ? l10n.uiPrevRecord(sceneClock(l10n, prev, t.waves.tickMs)) : null,
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
      rewards: sceneRewardItems(l10n, gems: end.gems, pieces: end.pieces),
      failed: !cleared && (end.reason == 'sunk' || end.reason == 'timeout'),
    );
  }
}

/// 보상 칸(아이콘 + 글, 0인 것은 빼고) — [확인]을 누르면 아이콘이 위 막대로 날아간다.
List<SceneRewardItem> sceneRewardItems(AppLocalizations l, {int gems = 0, int cards = 0, int pieces = 0}) => [
  if (gems > 0) (icon: UiSprites.gem, text: l.uiSceneGems(gems)),
  if (cards > 0) (icon: UiSprites.cardBack, text: l.uiSceneCards(cards)),
  if (pieces > 0) (icon: UiSprites.tabMap, text: l.uiScenePieces(pieces)),
];

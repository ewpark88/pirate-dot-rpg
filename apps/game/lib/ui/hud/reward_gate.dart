import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/power/power_channel.dart';
import 'package:pirate_dot/power_policy.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/widgets/reward_burst.dart';

/// 상자를 연 뒤 전장 연출(S3 V자 빛줄기·솟는 금화)이 먼저 지나가게 기다리는 시간(S1: 상자 탭 → 전장 0.6초 → 창 + 덮개).
const chestBurstDelay = Duration(milliseconds: 600);

/// 절전·발열(보통 이상)이면 보상 터짐을 가볍게.
bool rewardLite(WidgetRef ref) =>
    ref.read(gameStateProvider).settings.powerSave ||
    ref.read(thermalLevelProvider).index >= ThermalLevel.moderate.index;

/// 보상 터짐(디자인 개편 ③)을 창 밖에서 받는 보상에 띄운다: 보물상자(ChestOpened — 전장 연출 뒤 [chestBurstDelay]) ·
/// 도감 수집 보상(CollectionRewardClaimed — 바로). 보스 보상은 BossDamageGate가 처치 창 전에 띄운다.
/// 빠른 항해·현상금 중에는 띄우지 않는다(요약 창이 따로 있다).
class RewardGate extends ConsumerStatefulWidget {
  const RewardGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RewardGate> createState() => _RewardGateState();
}

class _RewardGateState extends ConsumerState<RewardGate> {
  StreamSubscription<RecordedTick>? _sub;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      if (tick.frame.fastSail != null || tick.frame.bounty != null) return;
      for (final e in tick.events) {
        switch (e) {
          case ChestOpened(:final gold) when !gold.isZero:
            _later(
              chestBurstDelay,
              [(icon: UiSprites.coin, label: gold.format(), tier: RewardTier.gold)],
              source: UiSprites.chest,
              opened: UiSprites.chestOpen,
              tier: RewardTier.blue,
            );
          case CollectionRewardClaimed(:final at, :final gems, :final summons):
            final ats = [
              for (final r in collectionRewards(ref.read(gameStateProvider), ref.read(tablesProvider))) r.at,
            ];
            final i = ats.indexOf(at).clamp(0, RewardTier.values.length - 1);
            _later(
              Duration.zero,
              [
                if (gems > 0) (icon: UiSprites.gem, label: '$gems', tier: RewardTier.blue),
                if (summons > 0) (icon: UiSprites.tabSummon, label: '$summons', tier: RewardTier.purple),
              ],
              source: UiSprites.book,
              tier: RewardTier.values[i],
            );
          default:
        }
      }
    });
  }

  void _later(
    Duration wait,
    List<RewardItem> items, {
    required String source,
    required RewardTier tier,
    String? opened,
  }) {
    if (items.isEmpty) return;
    _timers.add(
      Timer(wait, () {
        if (!mounted) return;
        unawaited(
          showRewardBurst(
            context,
            items: items,
            source: source,
            openedSource: opened,
            tier: tier,
            lite: rewardLite(ref),
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

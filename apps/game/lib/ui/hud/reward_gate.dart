import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/power/power_channel.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/power_policy.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/widgets/reward_burst.dart';

/// 상자를 연 뒤 전장 연출(S3 V자 빛줄기·솟는 금화)이 먼저 지나가게 기다리는 시간(S1: 상자 탭 → 전장 0.6초 → 창 + 덮개).
const chestBurstDelay = Duration(milliseconds: 600);

/// 보상 터짐을 가볍게(빛줄기·별 줄이고 회전 없음): 절전 · 발열(보통 이상) · 설정 번쩍임 끔(접근성, S4).
/// 기기 '애니메이션 줄이기'는 RewardBurst가 직접 본다(MediaQuery.disableAnimations).
bool rewardLite(WidgetRef ref) {
  final s = ref.read(gameStateProvider).settings;
  return s.powerSave || !s.flash || ref.read(thermalLevelProvider).index >= ThermalLevel.moderate.index;
}

/// 보상 터짐(디자인 개편 ③)을 창 밖에서 받는 보상에 띄운다: 광고로 받은 보물상자(ChestOpened + adReward — 전장 연출 뒤 [chestBurstDelay]) ·
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
      // 광고로 받은 상자만 덮개(S1 결정 A — 상자는 몇 분마다라 그냥 받기는 S3 전장 연출만, 방치 피로 없음).
      // 광고 보상은 같은 틱에 SaveRequested(adReward)가 같이 온다. 젬을 고르면 금화 0 → 젬 칸(표 altGems).
      final ad = tick.events.any((e) => e is SaveRequested && e.reason == 'adReward');
      for (final e in tick.events) {
        switch (e) {
          case ChestOpened(:final gold) when ad:
            final gems = adDef(ref.read(tablesProvider), AdPlacement.chest).reward.integer('altGems');
            _later(
              chestBurstDelay,
              [
                if (gold.isZero)
                  (icon: UiSprites.gem, label: '$gems', tier: RewardTier.blue)
                else
                  (icon: UiSprites.coin, label: gold.format(), tier: RewardTier.gold),
              ],
              source: UiSprites.chest,
              opened: UiSprites.chestOpen,
              tier: RewardTier.gold,
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
          // 모든 '받기'를 같은 터짐으로(S1 2026-10-18): 패스 보상 · 구매 지급 · 탑·던전 소탕.
          case PassRewardClaimed(:final gems, :final paid) when gems > 0:
            _later(
              Duration.zero,
              [_gems(gems)],
              source: UiSprites.trophy,
              tier: paid ? RewardTier.purple : RewardTier.blue,
            );
          case PurchaseGranted(:final gems, :final summons, :final heroCards):
            _later(
              Duration.zero,
              [
                if (gems > 0) _gems(gems),
                if (summons > 0) (icon: UiSprites.tabSummon, label: '$summons', tier: RewardTier.purple),
                if (heroCards > 0) (icon: UiSprites.cardBack, label: '$heroCards', tier: RewardTier.purple),
              ],
              source: UiSprites.shop,
              tier: RewardTier.gold,
            );
          case TowerSwept(:final chestGems, :final chestCards):
            _later(
              Duration.zero,
              [
                if (chestGems > 0) _gems(chestGems),
                if (chestCards > 0) (icon: UiSprites.cardBack, label: '$chestCards', tier: RewardTier.purple),
              ],
              source: UiSprites.chest,
              opened: UiSprites.chestOpen,
              tier: RewardTier.blue,
            );
          case DungeonCleared(swept: true, :final gems, :final cards):
            _later(
              Duration.zero,
              [
                if (gems > 0) _gems(gems),
                if (cards.isNotEmpty) (icon: UiSprites.cardBack, label: '${cards.length}', tier: RewardTier.purple),
              ],
              source: UiSprites.chest,
              opened: UiSprites.chestOpen,
              tier: RewardTier.blue,
            );
          // 일일 퀘스트·출석·월간 젬은 이벤트 없이 저장 이유만 온다 → 이번 틱에 늘어난 젬으로.
          case SaveRequested(:final reason) when _gemClaims.contains(reason):
            final now = ref.read(gameStateProvider).wallet.gems;
            final got = now - _gemsSeen;
            if (got > 0) _later(Duration.zero, [_gems(got)], source: UiSprites.quest, tier: RewardTier.blue);
          default:
        }
      }
      _gemsSeen = ref.read(gameStateProvider).wallet.gems;
    });
    _gemsSeen = ref.read(gameStateProvider).wallet.gems;
    // 항해 패스 단계가 오르면 작은 토스트(S1 2026-10-18).
    final t = ref.read(tablesProvider);
    ref.listenManual(gameStateProvider.select((s) => passLevel(s, t)), (was, now) {
      if (was == null || now <= was || !mounted) return;
      showSkinToast(context, AppLocalizations.of(context).uiPassLevelUp(now));
    });
  }

  /// 젬 칸 하나.
  static RewardItem _gems(int n) => (icon: UiSprites.gem, label: '$n', tier: RewardTier.blue);

  /// 젬만 주고 이벤트가 없는 받기(저장 이유).
  static const _gemClaims = {'claimDaily', 'claimAttendance', 'claimGemSub'};

  /// 지난 틱 끝의 젬(이번 틱에 받은 양 = 지금 − 이것).
  int _gemsSeen = 0;

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

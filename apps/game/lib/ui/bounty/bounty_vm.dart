import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 현상금 사냥 UI 보기 모델 (기획 platform-content-bounty · 계약 B0 S2 292892a).
// 상태 = GameState.bounty · BattleView.bounty, 표 = meta.bounty, 명령 = StartBounty·SweepBounty·RetreatBounty,
// 결과 = BountyCleared·BountyFailed·BountySwept 이벤트(BountyResultGate가 [bountyResultProvider]에 넣는다).

/// 요일 보상 종류 (meta.bounty days[].reward.type — gifts는 경제가 젬으로 바꿔 준다).
enum BountyRewardKind { gems, cards, gifts, mapPieces }

BountyRewardKind _kind(String type) => switch (type) {
  'cards' => BountyRewardKind.cards,
  'gifts' => BountyRewardKind.gifts,
  'mapPieces' => BountyRewardKind.mapPieces,
  _ => BountyRewardKind.gems,
};

/// 요일 한 칸 (meta.bounty days). [weekday] 1=월 … 6=토 (일요일 '*'은 칸 없이 '아무 보스').
@immutable
class BountyDay {
  const BountyDay(this.weekday, this.bossId, this.reward, this.base, this.perTier);

  final int weekday;
  final String bossId;
  final BountyRewardKind reward;
  final double base;
  final double perTier;

  /// 단계 t 보상량 = floor(base + perTier × (t − 1)) (경제 bountyReward와 같은 식, 표시용).
  int amountAt(int tier) => (base + perTier * (tier - 1)).floor();
}

/// 월~토 현상금 보스 (표 순서).
final bountyDaysProvider = Provider<List<BountyDay>>((ref) {
  final c = ref.watch(tablesProvider).meta.raw.obj('bounty');
  return [
    for (final d in c.objs('days'))
      if (d.str('boss') != anyBoss)
        BountyDay(
          d.integer('weekday'),
          d.str('boss'),
          _kind(d.obj('reward').str('type')),
          d.obj('reward').number('base'),
          d.obj('reward').number('perTier'),
        ),
  ];
});

/// 티켓 상한 · 단계 상한 (meta.bounty ticketCap · maxTier).
final bountyLimitsProvider = Provider<({int ticketCap, int maxTier})>((ref) {
  final c = ref.watch(tablesProvider).meta.raw.obj('bounty');
  return (ticketCap: c.integer('ticketCap'), maxTier: c.integer('maxTier'));
});

/// 진행 중인 현상금 전투 (BattleView.bounty).
typedef BountyActive = ({String bossId, int tier, int ticksLeft});

/// 끝난 전투·소탕 결과 — 결과 작은 창이 한 번 보인다.
typedef BountyResult = ({bool success, String bossId, int tier, int amount, BountyRewardKind reward, double damage});

@immutable
class BountyVm {
  const BountyVm({
    this.tickets = 0,
    this.cleared = const {},
    this.progress = const {},
    this.adUsedToday = false,
    this.active,
    this.maxTier = 30,
  });

  final int tickets;
  final Map<String, int> cleared;
  final Map<String, double> progress;
  final bool adUsedToday;
  final BountyActive? active;
  final int maxTier;

  int clearedOf(String boss) => cleared[boss] ?? 0;

  /// 도전할 수 있는 가장 높은 단계 = 깬 최고 + 1 (상한).
  int openTierOf(String boss) => math.min(maxTier, clearedOf(boss) + 1);

  @override
  bool operator ==(Object other) =>
      other is BountyVm &&
      other.tickets == tickets &&
      mapEquals(other.cleared, cleared) &&
      mapEquals(other.progress, progress) &&
      other.adUsedToday == adUsedToday &&
      other.active == active &&
      other.maxTier == maxTier;

  @override
  int get hashCode => Object.hash(tickets, Object.hashAll(cleared.entries), adUsedToday, active, maxTier);
}

/// 오늘 요일 (기기 현지 날짜, 1=월 … 7=일).
final bountyWeekdayProvider = Provider<int>((ref) => ref.watch(clockProvider).now().toLocal().weekday);

/// [weekday]에 도전할 수 있는 보스인가 (일요일은 아무 보스).
bool bountyOpenOn(int weekday, BountyDay day) => weekday == DateTime.sunday || day.weekday == weekday;

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 현상금 보기 (GameState.bounty + BattleView.bounty).
final bountyProvider = Provider<BountyVm>((ref) {
  final maxTier = ref.watch(bountyLimitsProvider).maxTier;
  final today = _ymd(ref.watch(clockProvider).now().toLocal());
  return ref.watch(
    gameStateProvider.select((s) {
      final b = s.bounty;
      final v = s.battle?.bounty;
      return BountyVm(
        tickets: b?.tickets ?? 0,
        cleared: b?.cleared ?? const {},
        progress: b?.progress ?? const {},
        adUsedToday: b?.adOn == today,
        active: v == null ? null : (bossId: v.bossId, tier: v.tier, ticksLeft: v.ticksLeft),
        maxTier: maxTier,
      );
    }),
  );
});

/// 현상금 명령 창구 (계약 명령을 보낸다 — 결과는 상태·이벤트로 돌아온다).
final bountyCommandsProvider = Provider<BountyCommands>(BountyCommands.new);

class BountyCommands {
  BountyCommands(this._ref);

  final Ref _ref;

  /// 도전 — 경제 canStartBounty(오늘 보스·열린 단계·티켓·진행 중 아님)가 허락할 때만 보낸다. 보냈으면 true.
  bool start(String boss, int tier) {
    final s = _ref.read(gameStateProvider);
    final t = _ref.read(tablesProvider);
    if (!canStartBounty(s, t, _ref.read(clockProvider).now(), boss, tier)) return false;
    _ref.read(commandSinkProvider).send(StartBounty(boss, tier));
    return true;
  }

  /// 소탕 (깬 최고 단계로 count장 — 티켓이 모자라면 경제가 있는 만큼).
  void sweep(String boss, int count) => _ref.read(commandSinkProvider).send(SweepBounty(boss, count));

  /// 후퇴 = 실패(티켓 반환).
  void retreat() => _ref.read(commandSinkProvider).send(const RetreatBounty());
}

/// 끝난 전투·소탕 결과 (이벤트에서). 창을 닫으면 비운다.
final bountyResultProvider = NotifierProvider<BountyResultNotifier, BountyResult?>(BountyResultNotifier.new);

class BountyResultNotifier extends Notifier<BountyResult?> {
  @override
  BountyResult? build() => null;

  /// 이벤트 하나를 결과로 (관계없는 이벤트는 무시).
  void onEvent(GameEvent e) {
    state = switch (e) {
      BountyCleared(:final bossId, :final tier, :final reward) => (
        success: true,
        bossId: bossId,
        tier: tier,
        amount: reward.amount,
        reward: _kind(reward.type),
        damage: 1,
      ),
      BountySwept(:final bossId, :final tier, :final reward) => (
        success: true,
        bossId: bossId,
        tier: tier,
        amount: reward.amount,
        reward: _kind(reward.type),
        damage: 1,
      ),
      BountyFailed(:final bossId, :final tier, :final damageRatio) => (
        success: false,
        bossId: bossId,
        tier: tier,
        amount: 0,
        reward: BountyRewardKind.gems,
        damage: damageRatio,
      ),
      _ => state,
    };
  }

  void ack() => state = null;
}

/// 표 순서 (테스트·운영자용 — 표를 읽을 수 없을 때).
List<BountyDay> bountyDaysOf(GameTables t) => [
  for (final d in t.meta.raw.obj('bounty').objs('days'))
    if (d.str('boss') != anyBoss)
      BountyDay(
        d.integer('weekday'),
        d.str('boss'),
        _kind(d.obj('reward').str('type')),
        d.obj('reward').number('base'),
        d.obj('reward').number('perTier'),
      ),
];

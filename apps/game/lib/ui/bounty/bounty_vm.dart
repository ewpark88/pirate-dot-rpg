import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';

// 현상금 사냥 UI 보기 모델 (기획 platform-content-bounty · 계획 platform-bounty-topdown B4).
// 계약 B0(S2: StartBounty·SweepBounty·RetreatBounty·GameState.bounty·BattleView.bounty)이 오기 전까지
// [BountyController]가 기획 표 숫자로 흉내 낸다. 계약이 오면 컨트롤러·보기만 코어 값으로 바꾸고 화면은 그대로 둔다.

/// 요일 보상 종류 (bounty.json days[].reward.type).
enum BountyReward { gems, cards, gifts, mapPieces }

/// 요일 한 칸 (기획 3절 표). [weekday] 1=월 … 7=일. 일요일 [bossId]는 '*'(아무 보스).
@immutable
class BountyDay {
  const BountyDay(this.weekday, this.bossId, this.reward, this.base, this.perTier);

  final int weekday;
  final String bossId;
  final BountyReward reward;
  final double base;
  final double perTier;

  /// 단계 t 보상량 = floor(base + perTier × (t − 1)).
  int amountAt(int tier) => (base + perTier * (tier - 1)).floor();
}

const bountyDays = [
  BountyDay(1, 'giant_hermit', BountyReward.gems, 10, 1),
  BountyDay(2, 'thunder_ray', BountyReward.cards, 2, 0.2),
  BountyDay(3, 'iceberg_walrus', BountyReward.gifts, 2, 0.1),
  BountyDay(4, 'lava_whale', BountyReward.gems, 10, 1),
  BountyDay(5, 'kraken', BountyReward.cards, 2, 0.2),
  BountyDay(6, 'ghost_admiral', BountyReward.mapPieces, 1, 0.1),
];

/// 티켓 상한 · 단계 상한 (bounty.json ticketCap · maxTier).
const bountyTicketCap = 9;
const bountyMaxTier = 30;

/// 진행 중인 현상금 전투 (BattleView.bounty 자리).
typedef BountyActive = ({String bossId, int tier, int ticksLeft});

/// 끝난 전투 결과 (BountyCleared / BountyFailed 이벤트 자리) — 결과 작은 창이 한 번 보인다.
typedef BountyResult = ({bool success, String bossId, int tier, int amount, BountyReward reward, double damage});

@immutable
class BountyVm {
  const BountyVm({
    this.tickets = 3,
    this.cleared = const {},
    this.progress = const {},
    this.adUsedToday = false,
    this.active,
    this.result,
  });

  final int tickets;

  /// 보스별 깬 최고 단계.
  final Map<String, int> cleared;

  /// 보스별 다음 단계 최고 피해 비율 0~1.
  final Map<String, double> progress;
  final bool adUsedToday;
  final BountyActive? active;
  final BountyResult? result;

  int clearedOf(String boss) => cleared[boss] ?? 0;

  /// 도전할 수 있는 가장 높은 단계 = 깬 최고 + 1 (상한 30).
  int openTierOf(String boss) => math.min(bountyMaxTier, clearedOf(boss) + 1);

  BountyVm copyWith({
    int? tickets,
    Map<String, int>? cleared,
    Map<String, double>? progress,
    bool? adUsedToday,
    BountyActive? Function()? active,
    BountyResult? Function()? result,
  }) => BountyVm(
    tickets: tickets ?? this.tickets,
    cleared: cleared ?? this.cleared,
    progress: progress ?? this.progress,
    adUsedToday: adUsedToday ?? this.adUsedToday,
    active: active == null ? this.active : active(),
    result: result == null ? this.result : result(),
  );
}

/// 오늘 요일 (기기 현지 날짜, 1=월 … 7=일).
final bountyWeekdayProvider = Provider<int>((ref) => ref.watch(clockProvider).now().toLocal().weekday);

/// [weekday]에 도전할 수 있는 보스인가 (일요일은 아무 보스).
bool bountyOpenOn(int weekday, BountyDay day) => weekday == DateTime.sunday || day.weekday == weekday;

/// 현상금 상태·명령 창구. 지금은 가짜(로컬), 계약이 오면 명령을 보내고 상태는 GameState.bounty에서 읽는다.
final bountyProvider = NotifierProvider<BountyController, BountyVm>(BountyController.new);

class BountyController extends Notifier<BountyVm> {
  @override
  BountyVm build() => const BountyVm();

  BountyDay _day(String boss) => bountyDays.firstWhere((d) => d.bossId == boss);

  /// 도전 (티켓 −1, 현상금 전투로). 거절 규칙: 오늘 보스(일요일 아무)·열린 단계·티켓 ≥ 1.
  bool start(String boss, int tier) {
    final today = ref.read(bountyWeekdayProvider);
    if (state.tickets < 1 || !bountyOpenOn(today, _day(boss)) || tier > state.openTierOf(boss)) return false;
    state = state.copyWith(
      tickets: state.tickets - 1,
      active: () => (bossId: boss, tier: tier, ticksLeft: 600),
      result: () => null,
    );
    return true;
  }

  /// 소탕 (깬 최고 단계로 count장, 티켓이 모자라면 있는 만큼). 보상 결과를 창으로 보인다.
  int sweep(String boss, int count) {
    final best = state.clearedOf(boss);
    final n = math.min(count, state.tickets);
    if (best < 1 || n < 1) return 0;
    final day = _day(boss);
    state = state.copyWith(
      tickets: state.tickets - n,
      result: () => (
        success: true,
        bossId: boss,
        tier: best,
        amount: day.amountAt(best) * n,
        reward: day.reward,
        damage: 1,
      ),
    );
    return n;
  }

  /// 후퇴 = 실패(티켓 반환).
  void retreat() {
    final a = state.active;
    if (a == null) return;
    state = state.copyWith(
      tickets: state.tickets + 1,
      active: () => null,
      result: () =>
          (success: false, bossId: a.bossId, tier: a.tier, amount: 0, reward: _day(a.bossId).reward, damage: 0),
    );
  }

  /// 광고로 티켓 1장 (하루 1번).
  void adTicket() {
    if (state.adUsedToday) return;
    state = state.copyWith(tickets: state.tickets + 1, adUsedToday: true);
  }

  /// 결과 창을 닫았다.
  void ackResult() => state = state.copyWith(result: () => null);

  /// 테스트·운영자용: 상태를 통째로.
  // ignore: use_setters_to_change_properties — 가짜 상태 주입.
  void load(BountyVm vm) => state = vm;
}

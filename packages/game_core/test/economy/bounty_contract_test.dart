import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 현상금 B0 계약 (요청 platform-bounty-b0b2.md): JSON 왕복, 키 없음 = 기본, 엔진·UI가 부를 함수 4개.
void main() {
  final t = EconomyHarness.tables;
  final wednesday = DateTime(2026, 10, 14);
  final sunday = DateTime(2026, 10, 18);

  GameState withBounty(BountyState b) => EconomyHarness().newGame().copyWith(
    bounty: b,
    crews: const {'octo': CrewState(level: 5), 'turtle': CrewState(level: 5)},
  );

  test('명령·이벤트 JSON 왕복', () {
    for (final c in const <Command>[
      StartBounty('kraken', 3),
      SweepBounty('kraken', 2),
      RetreatBounty(),
      OpSetBountyTickets(9),
      OpSetWeekday(7),
      OpSetWeekday(),
    ]) {
      expect(Command.fromJson(c.toJson()).toJson(), c.toJson());
    }
    const reward = BountyReward(type: 'cards', amount: 2, crewId: 'octo');
    for (final e in const <GameEvent>[
      BountyStarted(1, bossId: 'kraken', tier: 3, timeLimitTicks: 600),
      BountyCleared(2, bossId: 'kraken', tier: 3, reward: reward),
      BountyFailed(3, bossId: 'kraken', tier: 3, damageRatio: 0.62, reason: 'sunk'),
      BountySwept(
        4,
        bossId: 'kraken',
        tier: 2,
        count: 3,
        reward: BountyReward(type: 'gems', amount: 33),
      ),
      BountyTicketsRefilled(5, count: 7),
    ]) {
      expect(GameEvent.fromJson(e.toJson()).toJson(), e.toJson());
    }
  });

  test('BountyState·BattleView.bounty 왕복, 없으면 JSON에 키가 없다', () {
    const b = BountyState(
      tickets: 4,
      refilledOn: '2026-10-15',
      cleared: {'kraken': 3},
      progress: {'kraken': 0.62},
      adOn: '2026-10-15',
      active: BountyActive(bossId: 'kraken', tier: 4),
    );
    expect(BountyState.fromJson(b.toJson()).toJson(), b.toJson());
    final s = withBounty(b);
    expect(SaveCodec.decode(SaveCodec.encode(s)).bounty!.toJson(), b.toJson());
    expect(BattleView.empty.toJson().containsKey('bounty'), isFalse);
    final v = BattleView.empty.copyWith(bounty: const BountyView(bossId: 'kraken', tier: 4, ticksLeft: 100));
    expect(BattleView.fromJson(v.toJson()).bounty!.toJson(), v.bounty!.toJson());
    expect(v.copyWith(clearBounty: true).bounty, isNull);
  });

  test('bountyBossHp: 단계 t = 스테이지 t × stagePerTier 보스 HP × 배율, 단계가 오르면 커진다', () {
    expect(bountyBossHp(t, 'kraken', 2) > bountyBossHp(t, 'kraken', 1), isTrue);
  });

  test('canStartBounty: 오늘 보스·열린 단계·티켓 (기준 2), 일요일은 아무 보스, weekday로 고정', () {
    final s = withBounty(const BountyState(tickets: 1, cleared: {'iceberg_walrus': 2}));
    expect(canStartBounty(s, t, wednesday, 'iceberg_walrus', 3), isTrue);
    expect(canStartBounty(s, t, wednesday, 'iceberg_walrus', 4), isFalse, reason: '열린 단계는 깬 단계 + 1까지');
    expect(canStartBounty(s, t, wednesday, 'thunder_ray', 1), isFalse, reason: '수요일에 화요일 보스');
    expect(canStartBounty(s, t, sunday, 'thunder_ray', 1), isTrue);
    expect(canStartBounty(s, t, wednesday, 'thunder_ray', 1, weekday: 2), isTrue);
    expect(canStartBounty(withBounty(const BountyState()), t, wednesday, 'iceberg_walrus', 1), isFalse, reason: '티켓 0');
    expect(canStartBounty(EconomyHarness().newGame(), t, wednesday, 'iceberg_walrus', 1), isFalse, reason: '상태 없음');
  });

  test('bountyReward·grantBountyReward: floor(base + perTier × (t − 1)), 카드는 보유 선원 결정론, 조각은 둘 다', () {
    final s = withBounty(const BountyState(tickets: 1));
    final gems = bountyReward(s, t, 'giant_hermit', 3, XorShiftRng(1));
    expect(gems, const BountyReward(type: 'gems', amount: 12));
    expect(grantBountyReward(s, t, gems).wallet.gems, s.wallet.gems + 12);
    final cards = bountyReward(s, t, 'kraken', 6, XorShiftRng(1));
    expect(cards, bountyReward(s, t, 'kraken', 6, XorShiftRng(1)));
    expect([cards.type, cards.amount, s.crews.containsKey(cards.crewId)], ['cards', 3, isTrue]);
    final pieces = grantBountyReward(s, t, bountyReward(s, t, 'ghost_admiral', 11, XorShiftRng(1)));
    expect(
      [pieces.wallet.mapPieces, pieces.progress.mapPiecesEarned],
      [s.wallet.mapPieces + 2, s.progress.mapPiecesEarned + 2],
    );
    expect(bountyReward(s, t, 'iceberg_walrus', 1, XorShiftRng(1)), const BountyReward(type: 'gems', amount: 20));
  });
}

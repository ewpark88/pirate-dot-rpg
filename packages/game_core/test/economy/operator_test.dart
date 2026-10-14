import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 경제 운영자 명령 (설계서 6.10, 스펙 economy-m1 운영자 모드).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  test('OpSetCrew: 미보유 선원을 레벨 지정으로 보유 + 도감, 범위 밖 레벨은 1~75로 자른다', () {
    var s = sys.handle(h.newGame(), const OpSetCrew('octo', level: 46), h.ctx)!;
    expect(s.crews['octo']!.level, 46);
    expect(s.collection, contains('octo'));
    s = sys.handle(s, const OpSetCrew('octo', level: 999), h.ctx)!;
    expect(s.crews['octo']!.level, t.growth.maxLevel);
    s = sys.handle(s, const OpSetCrew('octo', level: 0), h.ctx)!;
    expect(s.crews['octo']!.level, 1);
  });

  test('OpSetCrew: 모르는 선원은 무시', () {
    final s = sys.handle(h.newGame(), const OpSetCrew('nobody', level: 5), h.ctx)!;
    expect(s.crews, isEmpty);
  });

  test('OpGrant: 골드·젬·증표를 더하고 카드는 카드 받기 규칙으로', () {
    final s0 = h.newGame(gold: BigNum.from(5), gems: 1).copyWith(crews: {'octo': const CrewState(level: 3)});
    final s = sys.handle(
      s0,
      OpGrant(gold: BigNum.from(100), gems: 30, tokens: 7, cards: const {'octo': 3}),
      h.ctx,
    )!;
    expect(s.wallet.gold, BigNum.from(105));
    expect(s.wallet.gems, 31);
    expect(s.tokens, 7);
    expect(s.crews['octo']!.cards, 3);
    expect(s.crews['octo']!.exp, 3 * t.growth.cardExp['common']!);
  });

  test('OpSetShip: 아는 부위만, 0~maxLevel로 자른다', () {
    final s = sys.handle(h.newGame(), const OpSetShip({'cannon': 50, 'sail': 99, 'anchor': 3}), h.ctx)!;
    expect(s.ship.level('cannon'), 50);
    expect(s.ship.level('sail'), t.shipParts.byId('sail').maxLevel);
    expect(s.ship.parts.containsKey('anchor'), isFalse);
  });

  test('OpAdvanceClock: 마지막 저장 시각을 그만큼 과거로 → ClaimOffline이 그 시간을 보상', () {
    final s0 = h.newGame().copyWith(crews: {'octo': const CrewState(level: 5)});
    final s1 = sys.handle(s0, const OpAdvanceClock(Duration(hours: 2)), h.ctx)!;
    expect(s1.savedAt, EconomyHarness.start.subtract(const Duration(hours: 2)));
    sys.handle(s1, const ClaimOffline(), h.ctx);
    expect(h.of<OfflineReward>().single.seconds, const Duration(hours: 2).inSeconds);
  });
}

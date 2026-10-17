import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 선원 상세 '레벨을 올리는 이유' 값 (사용자 피드백 #12, crew_growth.dart).
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11);
  GameState with_(CrewState c) =>
      GameState.newGame(playerId: 'g', seed: 1, now: start).copyWith(crews: {'octo': c}, fleet: const ['octo']);

  test('한 레벨 = powerPerLevel 비율, 다음 DPS = 지금 × (1 + 비율), 카드 장수·승급까지 레벨', () {
    final v = crewGrowth(with_(const CrewState(level: 5)), t, 'octo')!;
    final g = t.growth;
    expect(v.levelGain, closeTo((1 + g.powerPerLevel * 5) / (1 + g.powerPerLevel * 4) - 1, 1e-12));
    expect(v.dpsNext.toDouble(), closeTo(v.dpsNow.toDouble() * (1 + v.levelGain), 1e-6 * v.dpsNow.toDouble()));
    expect(v.mergeLevels, 0);
    expect(v.cardsToLevel, greaterThan(0));
    expect(v.levelsToPromote, nextPromotion(t, 5)!.level - 5);
    expect(v.promoteGain, closeTo(g.promotionMultiplier - 1, 1e-12));
  });

  test('경험치가 차 있으면 지금 합치면 오르는 레벨 수, 카드 장수는 0 · 승급 문 앞이면 레벨 이득 0', () {
    final full = crewGrowth(with_(const CrewState(level: 5, exp: 3)), t, 'octo')!;
    expect(full.mergeLevels, greaterThan(0));
    expect(full.cardsToLevel, 0);
    final gate = nextPromotion(t, 1)!.level;
    final atGate = crewGrowth(with_(CrewState(level: gate)), t, 'octo')!;
    expect(atGate.levelGain, 0);
    expect(atGate.levelsToPromote, 0);
    expect(crewGrowth(with_(const CrewState()), t, 'nobody'), isNull);
  });

  test('교체 비교(#34): 혼자 초당 피해와 비율 — 레벨이 높은 쪽으로 바꾸면 1보다 크다', () {
    final s = GameState.newGame(playerId: 'g', seed: 1, now: start).copyWith(
      crews: const {'octo': CrewState(level: 5), 'pang': CrewState(level: 40)},
      fleet: const ['octo'],
    );
    final up = swapCompare(s, t, 'octo', 'pang');
    expect(up.ratio, greaterThan(1));
    expect(up.ratio, closeTo((up.dpsIn / up.dpsOut).toDouble(), 1e-9));
    expect(swapCompare(s, t, 'pang', 'octo').ratio, lessThan(1));
  });
}

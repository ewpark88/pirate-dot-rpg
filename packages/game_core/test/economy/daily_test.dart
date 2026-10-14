import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 스펙 economy-m3-meta 규칙 4~6, 수용 기준 7~9 (일일 초기화·퀘스트·출석).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  int target(String type) => t.meta.dailyQuests.firstWhere((q) => q.str('type') == type).integer('target');
  String id(String type) => t.meta.dailyQuests.firstWhere((q) => q.str('type') == type).str('id');

  test('기준 7: 날짜가 바뀌면 퀘스트·광고·받음 초기화, 출석 일차는 유지', () {
    final s0 = h.newGame().copyWith(
      daily: const DailyState(
        date: '2000-01-01',
        ads: {'chest': 3},
        quests: {'kill_500': 9},
        attendanceDay: 3,
        questsClaimed: {'kill_500'},
        attendanceClaimed: true,
      ),
    );
    final s = sys.update(s0, h.ctx);
    expect(s.daily.date, localDate(h.clock.now()));
    expect(s.daily.ads, isEmpty);
    expect(s.daily.quests, isEmpty);
    expect(s.daily.questsClaimed, isEmpty);
    expect(s.daily.attendanceClaimed, isFalse);
    expect(s.daily.attendanceDay, 3);
  });

  test('같은 날이면 update가 일일 값을 건드리지 않는다', () {
    final s0 = h.newGame();
    final s1 = addQuestProgress(s0, t, 'kill', 5);
    expect(sys.update(s1, h.ctx).daily.quests[id('kill')], 5);
  });

  test('퀘스트 진행: 목표에서 멈추고, 강화·소환은 경제가 센다', () {
    var s = addQuestProgress(h.newGame(), t, 'kill', target('kill') + 99);
    expect(s.daily.quests[id('kill')], target('kill'));
    s = s.copyWith(
      wallet: Wallet(gold: BigNum.from(1e9), gems: t.meta.summonCostGems),
      summonsTotal: 10,
    );
    s = sys.handle(s, const UpgradePart('cannon', times: 3), h.ctx)!;
    expect(s.daily.quests[id('upgrade')], 3);
    s = sys.handle(s, const Summon(), h.ctx)!;
    expect(s.daily.quests[id('summon')], 1);
  });

  test('기준 8: 끝난 퀘스트마다 젬 10, 같은 퀘스트는 다시 못 받음', () {
    var s = addQuestProgress(h.newGame(), t, 'upgrade', target('upgrade'));
    s = addQuestProgress(s, t, 'summon', target('summon'));
    expect(canClaimDaily(s, t), isTrue);
    final views = dailyQuests(s, t);
    expect(views.where((q) => q.done).map((q) => q.id).toSet(), {id('upgrade'), id('summon')});
    s = sys.handle(s, const ClaimDaily(), h.ctx)!;
    expect(s.wallet.gems, 2 * t.meta.dailyQuestRewardGems);
    expect(s.daily.questsClaimed, {id('upgrade'), id('summon')});
    expect(canClaimDaily(s, t), isFalse);
    final again = sys.handle(s, const ClaimDaily(), h.ctx)!;
    expect(again.wallet.gems, s.wallet.gems);
    s = addQuestProgress(s, t, 'kill', target('kill'));
    expect(canClaimDaily(s, t), isTrue);
  });

  test('ClaimDaily(questId)는 그 퀘스트만 받는다', () {
    var s = addQuestProgress(h.newGame(), t, 'upgrade', target('upgrade'));
    s = addQuestProgress(s, t, 'summon', target('summon'));
    s = sys.handle(s, ClaimDaily(id('summon')), h.ctx)!;
    expect(s.wallet.gems, t.meta.dailyQuestRewardGems);
    expect(s.daily.questsClaimed, {id('summon')});
    final notDone = sys.handle(s, ClaimDaily(id('kill')), h.ctx)!;
    expect(notDone.wallet.gems, s.wallet.gems);
  });

  test('기준 9: 출석은 빠져도 이어서, 같은 날 두 번 불가, 7일 다음은 1일', () {
    final rewards = t.meta.raw.obj('attendance').objs('rewards');
    var s = h.newGame().copyWith(daily: DailyState(date: localDate(h.clock.now()), attendanceDay: 3));
    expect(attendance(s, t, h.clock.now()).day, 4);
    s = sys.handle(s, const ClaimAttendance(), h.ctx)!;
    expect(s.wallet.gems, rewards[3].integer('gems'));
    expect(s.daily.attendanceDay, 4);
    expect(attendance(s, t, h.clock.now()).claimedToday, isTrue);
    final again = sys.handle(s, const ClaimAttendance(), h.ctx)!;
    expect(again.wallet.gems, s.wallet.gems);

    final last = h.newGame().copyWith(daily: DailyState(date: localDate(h.clock.now()), attendanceDay: 7));
    expect(attendance(last, t, h.clock.now()).day, 1);
  });

  test('출석 7일차: 영웅 이상 확정 소환 1회', () {
    final s0 = h.newGame().copyWith(daily: DailyState(date: localDate(h.clock.now()), attendanceDay: 6));
    final s = sys.handle(s0, const ClaimAttendance(), h.ctx)!;
    final r = h.of<CrewSummoned>().single.results.single;
    expect(rarityOrder.indexOf(r.rarity), greaterThanOrEqualTo(rarityOrder.indexOf('hero')));
    expect(s.crews.containsKey(r.crewId), isTrue);
    expect(s.daily.attendanceDay, 7);
  });
}

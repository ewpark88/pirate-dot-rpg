import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 스펙 economy-m3-meta 규칙 1~3, 수용 기준 1~6 (보물상자·광고 보상·순풍).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  final chest = t.ads.chest;
  final tickSec = t.waves.tickMs / Duration.millisecondsPerSecond;
  int ticks(num sec) => (sec / tickSec).round();
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  /// 튜토리얼 끝, 전투 중, 선원 있음.
  GameState playing({num gold = 0, int gems = 0}) => h
      .newGame(gold: BigNum.from(gold), gems: gems)
      .copyWith(battle: BattleView.empty, crews: {'octo': const CrewState(level: 5)}, clearTutorial: true);

  GameState at(GameState s, int tick) {
    h.ctx.tick = tick;
    return sys.update(s, h.ctx);
  }

  group('보물상자', () {
    test('기준 1: firstOfferAfterSec에 떠서 floatSec 뒤 가라앉는다', () {
      final first = ticks(t.ads.firstOfferAfterSec);
      var s = at(playing(), first - 1);
      expect(s.battle!.chest, isNull);
      s = at(s, first);
      final c = s.battle!.chest!;
      expect(h.of<ChestSpawned>(), hasLength(1));
      expect(c.ticksLeft, ticks(chest.number('floatSec')));
      // 탑다운(기본): 카메라 사각형 안, 배 둘레 밖.
      final top = t.waves.raw.obj('top');
      final dx = c.x - top.number('shipX');
      final dy = c.y - top.number('shipY');
      expect(dx.abs(), lessThanOrEqualTo(top.number('viewWidth') / 2));
      expect(dy.abs(), lessThanOrEqualTo(top.number('viewHeight') / 2));
      expect(dx * dx + dy * dy, greaterThan(top.number('shipRadius') * top.number('shipRadius')));
      for (var i = 1; i < ticks(chest.number('floatSec')); i++) {
        s = at(s, first + i);
      }
      expect(s.battle!.chest, isNotNull);
      s = at(s, first + ticks(chest.number('floatSec')));
      expect(s.battle!.chest, isNull);
    });

    test('다음 상자는 intervalSec마다', () {
      final next = ticks(t.ads.firstOfferAfterSec) + ticks(chest.number('intervalSec'));
      expect(at(playing(), next).battle!.chest, isNotNull);
      expect(at(playing(), next + 1).battle!.chest, isNull);
    });

    test('기준 2: 튜토리얼 중에는 뜨지 않는다 · OpSpawnChest는 지금 띄운다', () {
      final tut = playing().copyWith(tutorialStep: 2);
      expect(at(tut, ticks(t.ads.firstOfferAfterSec)).battle!.chest, isNull);
      expect(sys.handle(tut, const OpSpawnChest(), h.ctx)!.battle!.chest, isNotNull);
    });

    test('기준 3: TapChest → chestReward 골드, ChestOpened, 상자 없음 · 없으면 무시', () {
      final s0 = sys.handle(playing(gold: 7), const OpSpawnChest(), h.ctx)!;
      final reward = chestReward(s0, t);
      expect(reward > BigNum.zero, isTrue);
      final s = sys.handle(s0, const TapChest(), h.ctx)!;
      final cap = goldCapacity(s0, t); // 화물칸 용량까지
      final want = BigNum.from(7) + reward;
      expect(s.wallet.gold.closeTo(want < cap ? want : cap), isTrue);
      expect(h.of<ChestOpened>().single.gold, reward);
      expect(s.battle!.chest, isNull);
      expect(sys.handle(s, const TapChest(), h.ctx)!.wallet.gold, s.wallet.gold);
    });
  });

  group('광고 보상', () {
    final chestAd = t.ads.placements.firstWhere((p) => p.id == 'chest');

    test('상자 광고: 골드 ×5 또는 젬 30 (결정 ①), 횟수·퀘스트 집계', () {
      final s0 = sys.handle(playing(), const OpSpawnChest(), h.ctx)!;
      final gold = sys.handle(s0, const GrantAdReward(AdPlacement.chest, choice: 'gold'), h.ctx)!;
      final want = chestReward(s0, t).times(chestAd.reward.number('value'));
      final cap = goldCapacity(s0, t); // 화물칸 용량까지
      expect(gold.wallet.gold.closeTo(want < cap ? want : cap), isTrue);
      expect(gold.battle!.chest, isNull);
      expect(gold.daily.ads['chest'], 1);
      final gems = sys.handle(s0, const GrantAdReward(AdPlacement.chest, choice: 'gems'), h.ctx)!;
      expect(gems.wallet.gems, chestAd.reward.integer('altGems'));
      expect(gems.daily.quests.values.single, 1);
      expect(sys.handle(playing(), const GrantAdReward(AdPlacement.chest), h.ctx)!.daily.ads, isEmpty);
    });

    test('기준 5: 하루 총 25회·장치 한도를 넘으면 무시', () {
      final full = playing().copyWith(
        daily: DailyState(date: localDate(h.clock.now()), ads: {'tailwind': t.ads.dailyCap}),
      );
      expect(canWatchAd(full, t, AdPlacement.freeSummon), isFalse);
      expect(sys.handle(full, const GrantAdReward(AdPlacement.freeSummon), h.ctx)!.summonsTotal, 0);
      final limit = t.ads.placements.firstWhere((p) => p.id == 'freeSummon').dailyLimit!;
      final capped = playing().copyWith(
        daily: DailyState(date: localDate(h.clock.now()), ads: {'freeSummon': limit}),
      );
      expect(canWatchAd(capped, t, AdPlacement.freeSummon), isFalse);
    });

    test('무료 소환 광고: 젬 없이 1장', () {
      final s = sys.handle(playing().copyWith(summonsTotal: 10), const GrantAdReward(AdPlacement.freeSummon), h.ctx)!;
      expect(s.summonsTotal, 11);
      expect(h.of<CrewSummoned>().single.results, hasLength(1));
    });

    test('오프라인 ×2: ClaimOffline 뒤 한 번만 (결정 ④)', () {
      final away = playing().copyWith(savedAt: EconomyHarness.start.subtract(const Duration(hours: 2)));
      final claimed = sys.handle(away, const ClaimOffline(), h.ctx)!;
      expect(claimed.lastOfflineGold, isNotNull);
      final doubled = sys.handle(claimed, const GrantAdReward(AdPlacement.offline), h.ctx)!;
      final want = claimed.wallet.gold + claimed.lastOfflineGold!;
      final cap = goldCapacity(claimed, t).times(offlineCapScale(t)); // 광고 ×2도 복귀 보상과 같은 한도
      expect(doubled.wallet.gold.closeTo(want < cap ? want : cap), isTrue);
      expect(doubled.lastOfflineGold, isNull);
      expect(sys.handle(doubled, const GrantAdReward(AdPlacement.offline), h.ctx)!.wallet.gold, doubled.wallet.gold);
    });
  });

  group('순풍', () {
    final tw = t.ads.placements.firstWhere((p) => p.id == 'tailwind').reward;
    final dur = Duration(seconds: tw.integer('durationSec'));
    final maxStack = Duration(seconds: tw.integer('maxStackSec'));

    test('광고 1회 = durationSec, 남은 시간 계산', () {
      final s = sys.handle(playing(), const GrantAdReward(AdPlacement.tailwind), h.ctx)!;
      expect(tailwindRemaining(s, h.clock.now()), dur);
      expect(tailwindRemaining(s, h.clock.now().add(dur * 2)), Duration.zero);
    });

    test('기준 6: 상한 maxStackSec', () {
      final s0 = playing().copyWith(
        buffs: Buffs(tailwindUntil: h.clock.now().add(maxStack - const Duration(minutes: 10))),
      );
      final s = sys.handle(s0, const GrantAdReward(AdPlacement.tailwind), h.ctx)!;
      expect(tailwindRemaining(s, h.clock.now()), maxStack);
    });

    test('함포 지원 광고: bossSupportUntil = now + durationSec, 순풍은 함포 지원을 지우지 않는다', () {
      final bs = t.ads.placements.firstWhere((p) => p.id == 'bossSupport').reward;
      var s = sys.handle(playing(), const GrantAdReward(AdPlacement.bossSupport), h.ctx)!;
      final until = h.clock.now().add(Duration(seconds: bs.integer('durationSec')));
      expect(s.buffs.bossSupportUntil, until);
      expect(s.daily.ads['bossSupport'], 1);
      s = sys.handle(s, const GrantAdReward(AdPlacement.tailwind), h.ctx)!;
      expect(s.buffs.bossSupportUntil, until);
      expect(tailwindRemaining(s, h.clock.now()), dur);
    });

    test('OpGrantTailwind는 한도와 상관없이 같은 누적 규칙', () {
      final s = sys.handle(playing(), const OpGrantTailwind(Duration(minutes: 5)), h.ctx)!;
      expect(tailwindRemaining(s, h.clock.now()), const Duration(minutes: 5));
    });
  });
}

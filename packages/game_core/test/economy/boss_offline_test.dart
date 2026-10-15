import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 스펙 economy-m1 규칙 7(보스 카드)·8(오프라인), 수용 기준 12.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  int totalCards(GameState s) => s.crews.values.fold(0, (n, c) => n + c.cards);

  GameState atStage(GameState s, int stage, {int rebirths = 0}) => s.copyWith(
    progress: Progress(stage: stage, bestStage: stage, rebirths: rebirths),
  );

  GameState starter() => h.newGame().copyWith(
    crews: {'octo': const CrewState(level: 5), 'turtle': const CrewState(level: 5)},
    collection: {'octo', 'turtle'},
  );

  group('보스 카드 grantBossCards', () {
    test('첫 회차: starterFirstStage부터 starterEvery번째 보스마다 옥토에게 일반 카드 1장 (사용자 결정 C)', () {
      final b = t.growth.bossCards;
      var s = starter().copyWith(
        crews: {
          'octo': const CrewState(),
          'turtle': CrewState(level: t.growth.maxLevel),
        },
      );
      final lastStage = b.starterFirstStage + (b.starterCount - 1) * b.starterEvery;
      for (var stage = 1; stage <= lastStage; stage++) {
        s = grantBossCards(atStage(s, stage), h.ctx, ['turtle']);
      }
      final octo = s.crews['octo']!;
      expect(octo.exp, b.starterCount * t.growth.cardExp['common']!);
      expect(octo.level, 1); // 일반 고정 — 점프 없음
      // 승급 카드(3장)를 넘는 옥토 카드는 증표 (사용자 결정 A), 사이 보스 카드는 신화 Lv75 거북이에게 → 모두 증표
      final need = t.growth.promotions.first.cards;
      expect(octo.cards, need);
      var between = 0;
      for (var stage = 1; stage <= lastStage; stage++) {
        if (!b.isStarterStage(stage)) between += b.countAt(stage);
      }
      expect(s.tokens, (b.starterCount - need + between) * t.growth.tokenPerSurplusCard);
    });

    test('환생 뒤 스테이지 1~10은 2장, 출전 선원에게', () {
      final s0 = atStage(starter(), 8, rebirths: 1).copyWith(
        crews: {
          'octo': const CrewState(level: 5),
          'turtle': CrewState(level: t.growth.maxLevel),
        },
      );
      final s = grantBossCards(s0, h.ctx, ['turtle']);
      expect(s.tokens, 2 * t.growth.tokenPerSurplusCard);
      expect(s.crews['octo']!.cards, 0);
    });

    test('스테이지 11 이후 장수 = 1 + floor(stage/150)', () {
      for (final (stage, n) in [(11, 1), (150, 2), (300, 3)]) {
        final hs = EconomyHarness();
        // 신화 선원 → 카드가 모두 증표로 바뀌어 장수를 정확히 셀 수 있다.
        final s0 = atStage(
          hs.newGame(),
          stage,
          rebirths: 1,
        ).copyWith(crews: {'octo': CrewState(level: t.growth.maxLevel)});
        expect(grantBossCards(s0, hs.ctx, ['octo']).tokens, n * t.growth.tokenPerSurplusCard, reason: 'stage $stage');
      }
    });

    test('환생 뒤에는 옥토 몰아주기가 없다', () {
      final s = grantBossCards(atStage(starter(), 1, rebirths: 1), h.ctx, ['turtle']);
      expect(s.crews['octo']!.cards, 0);
    });

    test('환생 3(사용자 결정 2026-10-15): 이미 깬 스테이지(bestStage 미만) 보스는 repeatEvery번째 스테이지에서만 repeatCount장', () {
      final b = t.growth.bossCards;
      int tokensAt(int stage, {required int best}) {
        final hs = EconomyHarness();
        final s0 = hs.newGame().copyWith(
          progress: Progress(stage: stage, bestStage: best, rebirths: 1),
          crews: {'octo': CrewState(level: t.growth.maxLevel)},
        );
        return grantBossCards(s0, hs.ctx, ['octo']).tokens ~/ t.growth.tokenPerSurplusCard;
      }

      final even = b.repeatEvery * 4; // 초반(1~10) 2장 구간 안의 반복 보스
      expect(tokensAt(even, best: 50), b.repeatCount);
      expect(tokensAt(even + 1, best: 50), 0);
      expect(tokensAt(even * 10, best: 300), b.repeatCount);
      // 역대 최고 스테이지의 보스(bestStage 이상)는 처음 잡는 보스 — 원래 장수
      expect(tokensAt(50, best: 50), b.countAt(50));
      expect(tokensAt(51, best: 50), b.countAt(51));
    });

    test('첫 회차에는 반복 보스 규칙이 없다', () {
      final hs = EconomyHarness();
      final s0 = hs.newGame().copyWith(
        progress: const Progress(stage: 21, bestStage: 30),
        crews: {'octo': CrewState(level: t.growth.maxLevel)},
      );
      expect(
        grantBossCards(s0, hs.ctx, ['octo']).tokens,
        t.growth.bossCards.countAt(21) * t.growth.tokenPerSurplusCard,
      );
    });

    test('출전이 비면 시작 카드 외에는 주지 않는다', () {
      final s0 = atStage(starter(), 20, rebirths: 1);
      expect(totalCards(grantBossCards(s0, h.ctx, const <String>[])), 0);
    });
  });

  group('오프라인 보상 ClaimOffline', () {
    GameState away(Duration d) => starter().copyWith(savedAt: EconomyHarness.start.subtract(d));

    test('초당 골드 추정 = 한 파 골드 / (max(한 파 HP ÷ DPS, 최소 파 시간) + 이동 시간)', () {
      final s = starter();
      final fleet = ['octo', 'turtle'];
      final dps = fleetDps(s, t, fleet);
      expect(dps > BigNum.zero, isTrue);
      final w = t.waves;
      final n = w.mobCountAt(1);
      final waveGold = BigNum.from(w.goldBase * n);
      final waveHp = BigNum.from(w.hpBase * w.waveHpPoolFactor * n);
      final waveSec = math.max((waveHp / dps).toDouble(), t.meta.offlineMinWaveSec);
      final expected = waveGold / BigNum.from(waveSec + w.travelSec);
      expect(goldPerSecEstimate(s, t, fleet).closeTo(expected), isTrue);
    });

    test('기준 12: 10시간 떠나 있었으면 8시간분 골드(× 효율)와 카드 3장', () {
      final s0 = away(const Duration(hours: 10));
      final s = sys.handle(s0, const ClaimOffline(), h.ctx)!;
      final e = h.of<OfflineReward>().single;
      expect(e.seconds, t.meta.offlineMaxSec);
      expect(e.cards, t.meta.offlineCardsPerMax);
      final gps = goldPerSecEstimate(s0, t, offlineFleet(s0, t));
      expect(e.gold.closeTo(gps.times(t.meta.offlineMaxSec * t.meta.offlineEfficiency)), isTrue);
      expect(s.wallet.gold.closeTo(e.gold), isTrue);
      expect(s.savedAt, EconomyHarness.start);
      expect(h.of<SaveRequested>(), hasLength(1));
    });

    test('카드는 시간에 비례(내림): 4시간 → 1장', () {
      sys.handle(away(const Duration(hours: 4)), const ClaimOffline(), h.ctx);
      expect(h.of<OfflineReward>().single.cards, 1);
    });

    test('기준 12: 저장 시각이 미래(시계 역행)면 0, 이벤트 없음', () {
      final s0 = starter().copyWith(savedAt: EconomyHarness.start.add(const Duration(hours: 3)));
      final s = sys.handle(s0, const ClaimOffline(), h.ctx)!;
      expect(s.wallet.gold, BigNum.zero);
      expect(h.events, isEmpty);
    });

    test('한 번 받으면 다시 받을 것이 없다', () {
      final s1 = sys.handle(away(const Duration(hours: 1)), const ClaimOffline(), h.ctx)!;
      h.events.clear();
      sys.handle(s1, const ClaimOffline(), h.ctx);
      expect(h.events, isEmpty);
    });
  });
}

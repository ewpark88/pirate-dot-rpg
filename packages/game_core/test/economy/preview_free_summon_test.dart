import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 복귀 팝업 미리보기(UI 레인 요청)와 첫 10연 무료(설계서 4.9·4.12, 사용자 결정 2026-10-14).
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  late EconomyHarness h;

  setUp(() => h = EconomyHarness());

  group('offlinePreview', () {
    GameState away(Duration d) =>
        h.newGame().copyWith(crews: {'octo': const CrewState(level: 5)}, savedAt: EconomyHarness.start.subtract(d));

    test('ClaimOffline과 같은 초·골드·카드 수', () {
      final s0 = away(const Duration(hours: 5));
      final p = offlinePreview(s0, t, EconomyHarness.start)!;
      final s = sys.handle(s0, const ClaimOffline(), h.ctx)!;
      final e = h.of<OfflineReward>().single;
      expect(p.seconds, e.seconds);
      expect(p.gold, e.gold);
      expect(p.cards, e.cards);
      final cap = goldCapacity(s0, t).times(offlineCapScale(t)); // 화물칸 용량 × offline.capMultiplier까지
      expect(s.wallet.gold, p.gold < cap ? p.gold : cap);
    });

    test('8시간 상한, 효율 계수 포함', () {
      final s0 = away(const Duration(hours: 20));
      final p = offlinePreview(s0, t, EconomyHarness.start)!;
      expect(p.seconds, t.meta.offlineMaxSec);
      final gps = goldPerSecEstimate(s0, t, offlineFleet(s0, t));
      expect(p.gold.closeTo(gps.times(t.meta.offlineMaxSec * t.meta.offlineEfficiency)), isTrue);
    });

    test('5분 미만 부재(광고 시청·앱 껐다 켜기)는 복귀 창도 보상도 없다 — 사용자 신고 2026-10-15', () {
      expect(t.meta.offlineMinSec, 300);
      expect(offlinePreview(away(const Duration(minutes: 4, seconds: 59)), t, EconomyHarness.start), isNull);
      expect(offlinePreview(away(const Duration(seconds: 30)), t, EconomyHarness.start), isNull);
      expect(offlinePreview(away(const Duration(minutes: 5)), t, EconomyHarness.start), isNotNull);
    });

    test('offline.minSec 미만이거나 시계 역행이면 null, ClaimOffline도 아무것도 안 함', () {
      final short = away(Duration(seconds: t.meta.offlineMinSec - 1));
      expect(offlinePreview(short, t, EconomyHarness.start), isNull);
      sys.handle(short, const ClaimOffline(), h.ctx);
      expect(h.events, isEmpty);
      expect(offlinePreview(away(const Duration(hours: -1)), t, EconomyHarness.start), isNull);
    });
  });

  group('첫 10연 무료', () {
    test('튜토리얼 보스 뒤 summonsTotal 0이면 10연이 무료, 영웅 정확히 1장 + 나머지 희귀 이하, total += 10', () {
      for (var seed = 1; seed <= 100; seed++) {
        final hs = EconomyHarness(seed: seed);
        final s0 = hs.newGame().copyWith(progress: const Progress(stage: 4, bestStage: 4));
        expect(summonCostFor(s0, t, 10), 0);
        expect(canSummon(s0, t, 10), isTrue);
        final s = sys.handle(s0, const Summon(count: 10), hs.ctx)!;
        expect(s.wallet.gems, 0);
        expect(s.summonsTotal, 10);
        final results = hs.of<CrewSummoned>().single.results;
        final tut = t.meta.raw.obj('tutorial');
        final max = rarityOrder.indexOf(tut.str('firstTenMaxRarity'));
        expect(results.where((r) => r.rarity == tut.str('firstTenGuarantee')), hasLength(1), reason: 'seed $seed');
        expect(results.where((r) => rarityOrder.indexOf(r.rarity) > max), hasLength(1), reason: 'seed $seed');
      }
    });

    test('튜토리얼 보스(스테이지 3)를 잡기 전에는 무료가 아니다 (튜토리얼 4단계 순서)', () {
      expect(summonCostFor(h.newGame(), t, 10), t.meta.summonCostGems * 10);
      final s3 = h.newGame().copyWith(progress: const Progress(stage: 3, bestStage: 3));
      expect(summonCostFor(s3, t, 10), t.meta.summonCostGems * 10);
    });

    test('1회 소환은 무료가 아니다', () {
      final s0 = h.newGame();
      expect(summonCostFor(s0, t, 1), t.meta.summonCostGems);
      expect(canSummon(s0, t, 1), isFalse);
    });

    test('무료 10연을 쓴 뒤에는 젬을 낸다, 일반 소환도 total을 올린다', () {
      final s0 = h.newGame(gems: t.meta.summonCostGems * 11).copyWith(summonsTotal: 10);
      expect(summonCostFor(s0, t, 10), t.meta.summonCostGems * 10);
      final s = sys.handle(s0, const Summon(), h.ctx)!;
      expect(s.summonsTotal, 11);
      expect(s.wallet.gems, t.meta.summonCostGems * 10);
    });
  });
}

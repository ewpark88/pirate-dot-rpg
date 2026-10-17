import 'package:game_core/game_core.dart';
import 'package:game_core/src/economy/economy_system.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// 유료 상품(계약 platform-iap, iap.json): 지급·토큰 중복 막기·첫 구매 2배·계정당 한도·구독 기간·회수·월간 젬·2배속·오프라인 12시간.
void main() {
  const sys = EconomySystem();
  final t = EconomyHarness.tables;
  final at = EconomyHarness.start;

  GameState buy(EconomyHarness h, GameState s, String id, String token, {DateTime? when}) =>
      sys.handle(s, GrantPurchase(id, token, when ?? at), h.ctx) ?? s;

  test('젬 팩: 첫 구매 2배, 같은 토큰은 다시 안 줌, 두 번째는 정가', () {
    final h = EconomyHarness();
    final gems = t.iap.products['gem_650']!.gems;
    var s = buy(h, h.newGame(), 'gem_650', 'a');
    expect(s.wallet.gems, gems * 2);
    expect(identical(buy(h, s, 'gem_650', 'a'), s), isTrue, reason: '같은 토큰');
    s = buy(h, s, 'gem_650', 'b');
    expect(s.wallet.gems, gems * 3);
    expect(s.purchaseTokens, ['a', 'b']);
    expect(h.of<PurchaseGranted>().map((e) => e.gems), [gems * 2, gems]);
    expect(h.of<SaveRequested>(), hasLength(2));
  });

  test('스타터 팩: 계정당 1회 — 젬 + 영웅 확정 1 + 스킨', () {
    final h = EconomyHarness();
    var s = buy(h, h.newGame().copyWith(summonsTotal: 10), 'starter_pack', 'a');
    expect(s.wallet.gems, t.iap.products['starter_pack']!.gems);
    expect(h.of<CrewSummoned>().single.results.single.rarity, 'hero');
    expect(s.ship.skinsOwned, contains('sprout'));
    final again = buy(h, s, 'starter_pack', 'b');
    expect(identical(again, s), isTrue, reason: '한도 1');
    s = again;
  });

  test('구독: 30일 권리, 갱신은 남은 기간에 이어 붙임, 만료·회수, 영구가 이긴다', () {
    final h = EconomyHarness();
    var s = buy(h, h.newGame(), 'no_ads_30d', 'a');
    expect(entitlementActive(s, 'noAds', at.add(const Duration(days: 29))), isTrue);
    expect(entitlementActive(s, 'noAds', at.add(const Duration(days: 31))), isFalse);
    s = buy(h, s, 'no_ads_30d', 'b', when: at.add(const Duration(days: 10)));
    expect(s.entitlements['noAds']!.until, at.add(const Duration(days: 60)));
    s = sys.handle(s, const RevokeEntitlement('noAds'), h.ctx)!;
    expect(entitlementActive(s, 'noAds', at), isFalse);
    s = buy(h, buy(h, s, 'no_ads', 'c'), 'no_ads_30d', 'd');
    expect(s.entitlements['noAds']!.until, isNull, reason: '영구 뒤 구독은 영구 그대로');
    expect(GameState.fromJson(s.toJson()).entitlements['noAds']!.until, isNull);
  });

  test('월간 젬: 즉시 젬 + 하루 한 번 gemSubDaily, 같은 날 두 번 없음', () {
    final h = EconomyHarness();
    var s = buy(h, h.newGame(), 'gem_monthly', 'a');
    final now = s.wallet.gems;
    expect(canClaimGemSub(s, h.clock.now()), isTrue);
    s = sys.handle(s, const ClaimGemSub(), h.ctx)!;
    expect(s.wallet.gems, now + t.iap.gemSubDaily);
    expect(canClaimGemSub(s, h.clock.now()), isFalse);
    expect(GameState.fromJson(s.toJson()).entitlements['gemSub']!.claimedOn, localDate(h.clock.now()));
  });

  test('2배속·오프라인 12시간·선장 패키지(광고 제거 + 2배속)', () {
    final h = EconomyHarness();
    final s0 = h.newGame();
    expect(purchasedSpeed(s0, t, at), isNull);
    final s = buy(h, s0, 'captain_pack', 'a');
    expect(purchasedSpeed(s, t, at), t.iap.speedMultiplier);
    expect(entitlementActive(s, 'noAds', at), isTrue);
    expect(offlineMaxSec(s0, t), t.meta.offlineMaxSec);
    final o = buy(h, s0, 'offline_12h', 'b');
    expect(offlineMaxSec(o, t), t.iap.offlineHours * Duration.secondsPerHour);
  });

  test('모르는 상품은 아무것도 안 함', () {
    final h = EconomyHarness();
    final s = h.newGame();
    expect(identical(buy(h, s, 'nope', 'a'), s), isTrue);
  });
}

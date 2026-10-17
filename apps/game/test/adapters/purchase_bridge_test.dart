import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/ads/no_ads.dart';
import 'package:pirate_dot/adapters/purchase/billing_sdk.dart';
import 'package:pirate_dot/adapters/purchase/play_purchases.dart';
import 'package:pirate_dot/adapters/purchase/purchase_bridge.dart';
import 'package:pirate_dot/adapters/purchase/purchase_types.dart';
import 'package:pirate_dot/adapters/purchase/sim_billing_sdk.dart';
import 'package:pirate_dot/engine_host.dart';

/// 저장·완료 순서를 적는 저장소.
class _LogStore implements SaveStore {
  _LogStore(this.log);

  final List<String> log;

  @override
  Future<String?> read() async => null;

  @override
  Future<String?> readBackup() async => null;

  @override
  Future<void> write(String json) async => log.add('save');
}

/// 완료를 적는 흉내 SDK.
class _LogSim extends SimBillingSdk {
  _LogSim(this.log, {required super.prices});

  final List<String> log;

  @override
  Future<void> complete(SdkPurchase purchase, {required bool consumable}) async =>
      log.add('complete:${purchase.productId}');
}

/// 결제 다리(계약 platform-iap 4절 순서 — 지급 → 저장 → 완료)를 실제 엔진(EngineHost)·구매 흉내 SDK로.
void main() {
  final t = GameTables.load();
  final start = DateTime.utc(2026, 11, 2, 3);
  late List<String> log;
  late EngineHost host;
  late _LogSim sim;
  late PlayPurchases shop;
  late PurchaseBridge bridge;

  setUp(() {
    log = [];
    host = EngineHost(
      tables: t,
      initial: GameState.newGame(playerId: 'p', seed: 1, now: start),
      clock: ManualClock(start),
      store: _LogStore(log),
      autosaveEvery: const Duration(days: 1),
    )..step();
    log.clear();
    sim = _LogSim(log, prices: {for (final id in t.iap.products.keys) id: '₩1,000'});
    shop = PlayPurchases(sim, catalog: purchaseCatalog(t), packageName: 'repo.dot.pirate');
    bridge = PurchaseBridge(
      shop: shop,
      tables: t,
      send: host.send,
      state: () => host.state,
      ticks: host.ticks,
      save: host.save,
    )..start();
  });
  tearDown(() async {
    await bridge.dispose();
    await shop.dispose();
  });

  /// 엔진을 몇 틱 돌리며 비동기 흐름을 흘린다.
  Future<void> pump([int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await Future<void>.delayed(Duration.zero);
      host.step();
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('젬 팩: 지급(엔진 토큰 기록) → 저장 → 완료 순서, 첫 구매 배수', () async {
    final gems = host.state.wallet.gems;
    await shop.buy('gem_120');
    await pump();
    final p = t.iap.products['gem_120']!;
    expect(host.state.wallet.gems, gems + p.gems * (p.firstBuyDouble ? t.iap.firstBuyMultiplier : 1));
    final i = log.indexOf('complete:gem_120');
    expect(i, greaterThan(0));
    expect(log.sublist(0, i), contains('save'), reason: '저장이 완료보다 먼저');
  });

  test('같은 토큰이 다시 와도(앱이 complete 전에 죽음) 두 번 지급하지 않고 완료만', () async {
    await shop.buy('gem_120');
    await pump();
    final gems = host.state.wallet.gems;
    final token = host.state.purchaseTokens.last;
    sim.replay(token, 'gem_120');
    await pump();
    expect(host.state.wallet.gems, gems);
  });

  test('광고 제거(비소모) → 권리, 환불 뒤 복원하면 회수, 광고 포트는 권리가 있으면 광고 없이 보상', () async {
    await shop.buy('no_ads');
    await pump();
    expect(entitlementActive(host.state, 'noAds', start), isTrue);
    final ads = EntitledAds(const NoAds(), noAds: () => entitlementActive(host.state, 'noAds', start));
    expect(ads.isReady(AdPlacement.chest), isTrue);
    expect(await ads.show(AdPlacement.chest), AdResult.rewarded);
    sim.refund('no_ads');
    await bridge.restore();
    await pump();
    expect(entitlementActive(host.state, 'noAds', start), isFalse);
  });

  test('대기·취소는 UI 소식으로', () async {
    final notices = <PurchaseUpdate>[];
    bridge.notices.listen(notices.add);
    sim.next = SimOutcome.pending;
    await shop.buy('gem_650');
    sim.next = SimOutcome.cancel;
    await shop.buy('gem_650');
    await pump(2);
    expect(notices.map((n) => n.runtimeType), [PurchasePending, PurchaseFailed]);
  });
}

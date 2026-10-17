import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/adapters/purchase/play_purchases.dart';
import 'package:pirate_dot/adapters/purchase/purchase_types.dart';
import 'package:pirate_dot/adapters/purchase/sim_billing_sdk.dart';

/// 운영자 '구매 흉내': 실제와 같은 PlayPurchases 흐름으로 성공·취소·대기·실패·환불을 낸다.
void main() {
  const catalog = {'gems_small': ProductKind.consumable, 'no_ads': ProductKind.nonConsumable};
  late SimBillingSdk sim;
  late PlayPurchases shop;
  late List<PurchaseUpdate> got;

  setUp(() {
    sim = SimBillingSdk(prices: {'gems_small': '₩1,200', 'no_ads': '₩3,900'});
    shop = PlayPurchases(sim, catalog: catalog, packageName: 'repo.dot.pirate');
    got = [];
    shop.updates.listen(got.add);
  });
  tearDown(() => shop.dispose());

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('성공 → 지급해도 됨(검증 통과), 취소·실패는 그대로 알림', () async {
    await shop.buy('gems_small');
    sim.next = SimOutcome.cancel;
    await shop.buy('gems_small');
    sim.next = SimOutcome.error;
    await shop.buy('no_ads');
    await flush();
    expect(got[0], isA<PurchaseDelivered>());
    expect([for (final f in got.whereType<PurchaseFailed>()) f.reason], ['cancelled', 'error']);
  });

  test('대기 → 마치면 지급', () async {
    sim.next = SimOutcome.pending;
    await shop.buy('no_ads');
    await flush();
    expect(got.single, isA<PurchasePending>());
    sim.settlePending(consumable: (id) => catalog[id] == ProductKind.consumable);
    await flush();
    expect(got.last, isA<PurchaseDelivered>());
  });

  test('환불 → 다음 복원에서 회수, 남은 소유는 restored로', () async {
    await shop.buy('no_ads');
    await flush();
    await shop.restore(active: {'no_ads'});
    await flush();
    expect(got.whereType<PurchaseDelivered>().last.restored, isTrue);
    expect(got.whereType<PurchaseRevoked>(), isEmpty);
    sim.refund('no_ads');
    await shop.restore(active: {'no_ads'});
    await flush();
    expect(got.whereType<PurchaseRevoked>().single.productId, 'no_ads');
  });

  test('상품 정보: 흉내 가격', () async {
    final list = await shop.products({'no_ads'});
    expect(list.single.price, '₩3,900');
  });
}

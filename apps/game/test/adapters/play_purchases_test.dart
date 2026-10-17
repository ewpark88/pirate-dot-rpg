import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/adapters/purchase/billing_sdk.dart';
import 'package:pirate_dot/adapters/purchase/play_purchases.dart';
import 'package:pirate_dot/adapters/purchase/purchase_types.dart';

/// 가짜 Play 결제: 시험이 [emit]으로 SDK 소식을 넣는다.
class FakeBilling implements BillingSdk {
  bool ok = true;
  bool opens = true;
  bool restoreFails = false;
  List<SdkPurchase> owned = [];
  final bought = <(String, bool)>[];
  final completed = <(String, bool)>[];
  final _stream = StreamController<List<SdkPurchase>>.broadcast();

  void emit(List<SdkPurchase> batch) => _stream.add(batch);

  @override
  Future<bool> isAvailable() async => ok;

  @override
  Future<List<SdkProduct>> query(Set<String> ids) async => [
    for (final id in ids) SdkProduct(id: id, price: '₩1,200', currency: 'KRW', micros: 1200000000),
  ];

  @override
  Future<bool> buy(String productId, {required bool consumable}) async {
    bought.add((productId, consumable));
    return opens;
  }

  @override
  Stream<List<SdkPurchase>> get purchases => _stream.stream;

  @override
  Future<void> restore() async {
    if (restoreFails) throw StateError('offline');
    emit(owned);
  }

  @override
  Future<void> complete(SdkPurchase purchase, {required bool consumable}) async =>
      completed.add((purchase.token, consumable));
}

void main() {
  const catalog = {
    'gems_small': ProductKind.consumable,
    'no_ads': ProductKind.nonConsumable,
    'pass': ProductKind.subscription,
  };
  late FakeBilling sdk;
  late PlayPurchases shop;
  late List<PurchaseUpdate> got;

  setUp(() {
    sdk = FakeBilling();
    shop = PlayPurchases(sdk, catalog: catalog, packageName: 'repo.dot.pirate');
    got = [];
    shop.updates.listen(got.add);
  });
  tearDown(() => shop.dispose());

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  SdkPurchase bought(String id, {String token = 't1', String? pkg = 'repo.dot.pirate', bool restored = false}) =>
      SdkPurchase(
        productId: id,
        status: restored ? SdkPurchaseStatus.restored : SdkPurchaseStatus.purchased,
        token: token,
        packageName: pkg,
        at: DateTime.utc(2026, 10, 18),
        needsComplete: true,
      );

  test('구매: 대기 → 지급해도 됨(토큰) → complete는 앱이 부를 때만, 소모형이면 consume', () async {
    await shop.buy('gems_small');
    expect(sdk.bought, [('gems_small', true)]);
    sdk
      ..emit([const SdkPurchase(productId: 'gems_small', status: SdkPurchaseStatus.pending)])
      ..emit([bought('gems_small')]);
    await flush();
    expect(got[0], isA<PurchasePending>());
    expect(
      got[1],
      isA<PurchaseDelivered>().having((d) => d.token, 'token', 't1').having((d) => d.restored, 'r', false),
    );
    expect(sdk.completed, isEmpty, reason: '지급·저장 전에는 완료하지 않는다(죽어도 Play가 다시 보냄)');
    await shop.complete('t1');
    expect(sdk.completed, [('t1', true)]);
    await shop.complete('t1');
    expect(sdk.completed, hasLength(1), reason: '두 번 완료하지 않음');
  });

  test('비소모형은 acknowledge(consumable false)', () async {
    await shop.buy('no_ads');
    sdk.emit([bought('no_ads', token: 'n1')]);
    await flush();
    await shop.complete('n1');
    expect(sdk.bought, [('no_ads', false)]);
    expect(sdk.completed, [('n1', false)]);
  });

  test('취소·오류·이미 보유·결제 불가·모르는 상품·창 못 띄움', () async {
    sdk.emit([
      const SdkPurchase(productId: 'no_ads', status: SdkPurchaseStatus.canceled),
      const SdkPurchase(productId: 'no_ads', status: SdkPurchaseStatus.error, error: 'alreadyOwned'),
      const SdkPurchase(productId: 'pass', status: SdkPurchaseStatus.error, error: 'network'),
    ]);
    await flush(); // SDK 소식이 먼저 도착하게
    await shop.buy('unknown');
    sdk.opens = false;
    await shop.buy('pass');
    sdk.ok = false;
    await shop.buy('no_ads');
    await flush();
    expect(got.whereType<PurchaseFailed>().map((f) => f.reason), [
      'cancelled',
      'alreadyOwned',
      'error',
      'invalid',
      'error',
      'unavailable',
    ]);
    expect(await shop.products(catalog.keys.toSet()), isEmpty, reason: '결제 불가면 상품을 숨긴다');
  });

  test('로컬 검증: 다른 패키지·빈 토큰·모르는 상품은 invalid, 완료하지 않음(Play 자동 환불)', () async {
    sdk.emit([
      bought('no_ads', token: 'x', pkg: 'evil.app'),
      bought('no_ads', token: ''),
      bought('free_money', token: 'y'),
    ]);
    await flush();
    expect(got.whereType<PurchaseFailed>().map((f) => f.reason), ['invalid', 'invalid', 'invalid']);
    expect(got.whereType<PurchaseDelivered>(), isEmpty);
    await shop.complete('x');
    expect(sdk.completed, isEmpty);
  });

  test('같은 토큰이 다시 와도 그대로 전한다 — 두 번 지급을 막는 것은 엔진(purchaseTokens)', () async {
    sdk
      ..emit([bought('gems_small', token: 'dup')])
      ..emit([bought('gems_small', token: 'dup')]);
    await flush();
    expect(got.whereType<PurchaseDelivered>(), hasLength(2));
  });

  test('복원: 받은 소유분은 restored로 지급, 권리 중 스토어에 없는 비소모·구독은 회수, 소모형은 무시', () async {
    sdk.owned = [bought('no_ads', token: 'r1', restored: true)];
    await shop.restore(active: {'no_ads', 'pass', 'gems_small'});
    await flush();
    expect(got.whereType<PurchaseDelivered>().single.restored, isTrue);
    expect(got.whereType<PurchaseRevoked>().map((r) => r.productId), ['pass']);
  });

  test('복원 실패(오프라인)면 아무것도 회수하지 않는다', () async {
    sdk.restoreFails = true;
    await shop.restore(active: {'no_ads', 'pass'});
    await flush();
    expect(got, isEmpty);
  });

  test('상품 정보: 우리 표에 있는 것만, 종류는 표에서', () async {
    final list = await shop.products({'pass', 'nope'});
    expect(list.single.id, 'pass');
    expect(list.single.kind, ProductKind.subscription);
    expect(list.single.price, '₩1,200');
  });

  test('NoPurchases: 상점 숨김', () async {
    const none = NoPurchases();
    expect(await none.available(), isFalse);
    expect(await none.products({'pass'}), isEmpty);
  });
}

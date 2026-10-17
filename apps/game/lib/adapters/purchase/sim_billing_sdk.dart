import 'dart:async';

import 'package:pirate_dot/adapters/purchase/billing_sdk.dart';

/// 운영자 '구매 흉내'가 고르는 다음 결과.
enum SimOutcome { success, cancel, pending, error }

/// 실제 결제 없이 구매 흐름을 흉내 내는 SDK(운영자 빌드 — 계약 요청서 platform-iap '그동안'). 운영자 패널이 [next]를 고르고,
/// [settlePending]으로 대기 중 결제를 마치며, [refund]로 소유분을 지워 다음 복원에서 회수되게 한다.
/// 판단(검증·순서·복원 차이)은 실제와 같은 PlayPurchases가 한다 — 여기는 소식만 만든다.
class SimBillingSdk implements BillingSdk {
  SimBillingSdk({required this.prices, this.packageName = 'repo.dot.pirate'});

  /// 상품 id → 보일 가격 글.
  final Map<String, String> prices;
  final String packageName;
  SimOutcome next = SimOutcome.success;
  final _stream = StreamController<List<SdkPurchase>>.broadcast();
  final Map<String, SdkPurchase> _owned = {}; // 비소모·구독 소유(상품 id별)
  final List<String> _pending = [];
  int _seq = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<SdkProduct>> query(Set<String> ids) async => [
    for (final id in ids)
      if (prices[id] case final p?) SdkProduct(id: id, price: p),
  ];

  @override
  Future<bool> buy(String productId, {required bool consumable}) async {
    switch (next) {
      case SimOutcome.cancel:
        _stream.add([SdkPurchase(productId: productId, status: SdkPurchaseStatus.canceled)]);
      case SimOutcome.error:
        _stream.add([SdkPurchase(productId: productId, status: SdkPurchaseStatus.error, error: 'sim')]);
      case SimOutcome.pending:
        _pending.add(productId);
        _stream.add([SdkPurchase(productId: productId, status: SdkPurchaseStatus.pending)]);
      case SimOutcome.success:
        _deliver(productId, consumable: consumable);
    }
    return true;
  }

  /// 대기 중 결제를 모두 마친다(편의점 결제가 끝난 것처럼).
  void settlePending({required bool Function(String id) consumable}) {
    final ids = List.of(_pending);
    _pending.clear();
    for (final id in ids) {
      _deliver(id, consumable: consumable(id));
    }
  }

  /// 같은 구매를 다시 보낸다(앱이 complete 전에 죽어 Play가 다음 실행에 다시 보내는 상황 흉내).
  void replay(String token, String productId) => _stream.add([
    SdkPurchase(
      productId: productId,
      status: SdkPurchaseStatus.purchased,
      token: token,
      packageName: packageName,
      at: DateTime.now().toUtc(),
      needsComplete: true,
    ),
  ]);

  /// 환불·구독 만료: 소유에서 지운다 — 다음 restore에서 PlayPurchases가 회수(Revoked)한다.
  void refund(String productId) => _owned.remove(productId);

  void _deliver(String productId, {required bool consumable}) {
    final p = SdkPurchase(
      productId: productId,
      status: SdkPurchaseStatus.purchased,
      token: 'sim-${++_seq}',
      packageName: packageName,
      at: DateTime.now().toUtc(),
      needsComplete: true,
    );
    if (!consumable) _owned[productId] = p;
    _stream.add([p]);
  }

  @override
  Stream<List<SdkPurchase>> get purchases => _stream.stream;

  @override
  Future<void> restore() async {
    _stream.add([
      for (final p in _owned.values)
        SdkPurchase(
          productId: p.productId,
          status: SdkPurchaseStatus.restored,
          token: p.token,
          packageName: p.packageName,
          at: p.at,
        ),
    ]);
  }

  @override
  Future<void> complete(SdkPurchase purchase, {required bool consumable}) async {}
}

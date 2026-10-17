import 'dart:async';

import 'package:pirate_dot/adapters/purchase/billing_sdk.dart';
import 'package:pirate_dot/adapters/purchase/purchase_types.dart';

/// Play 결제 흐름(계약 요청서 platform-iap 4·5절): SDK 소식을 [PurchaseUpdate]로 바꾸고, 로컬 검증을 하고,
/// 지급·저장이 끝났다고 앱이 [complete]를 부를 때까지 SDK 구매를 들고 있다.
///
/// - 검증(서버 없음 단계): 우리 표에 있는 상품 · 토큰 있음 · 패키지 이름 일치(알 때만). 아니면 [PurchaseFailed] invalid —
///   완료하지 않아 Play가 3일 뒤 자동 환불한다(이상한 구매에 보상을 주지 않음).
/// - 같은 토큰이 다시 와도(앱이 complete 전에 죽음) 그대로 [PurchaseDelivered] — 두 번 지급을 막는 것은 엔진(purchaseTokens)이다.
/// - 복원: SDK restore가 끝난 뒤 [restore]의 active 가운데 restored로 오지 않은 비소모·구독은 [PurchaseRevoked].
///   restore가 실패하면(오프라인 등) 아무것도 회수하지 않는다(잘못 끄지 않게).
class PlayPurchases implements PurchaseService {
  PlayPurchases(this._sdk, {required this.catalog, String? packageName}) : _package = packageName {
    _sub = _sdk.purchases.listen(_onSdk);
  }

  final BillingSdk _sdk;

  /// 우리 상품 표(iap.json — S2): id → 종류.
  final Map<String, ProductKind> catalog;
  final String? _package;
  final _out = StreamController<PurchaseUpdate>.broadcast();
  late final StreamSubscription<List<SdkPurchase>> _sub;

  /// complete를 기다리는 SDK 구매(토큰별).
  final Map<String, SdkPurchase> _waiting = {};

  /// 지금 진행 중인 restore가 받은 상품(null = restore 중 아님).
  Set<String>? _restoring;

  @override
  Stream<PurchaseUpdate> get updates => _out.stream;

  @override
  Future<bool> available() => _sdk.isAvailable();

  @override
  Future<List<ProductInfo>> products(Set<String> ids) async {
    final known = ids.where(catalog.containsKey).toSet();
    if (known.isEmpty || !await _sdk.isAvailable()) return const [];
    return [
      for (final p in await _sdk.query(known))
        ProductInfo(id: p.id, kind: catalog[p.id]!, price: p.price, currency: p.currency, micros: p.micros),
    ];
  }

  @override
  Future<void> buy(String productId) async {
    final kind = catalog[productId];
    if (kind == null) return _out.add(PurchaseFailed(productId, 'invalid'));
    if (!await _sdk.isAvailable()) return _out.add(PurchaseFailed(productId, 'unavailable'));
    final opened = await _sdk.buy(productId, consumable: kind == ProductKind.consumable);
    if (!opened) _out.add(PurchaseFailed(productId, 'error'));
  }

  @override
  Future<void> restore({required Set<String> active}) async {
    _restoring = {};
    try {
      await _sdk.restore();
      await Future<void>.delayed(Duration.zero); // restore 끝에 같이 온 소식까지 받는다
    } on Object {
      _restoring = null;
      return; // 실패하면 회수하지 않는다
    }
    final seen = _restoring ?? const <String>{};
    _restoring = null;
    for (final id in active) {
      final kind = catalog[id];
      if (kind == null || kind == ProductKind.consumable) continue; // 소모형은 소유가 아니다
      if (!seen.contains(id)) _out.add(PurchaseRevoked(id));
    }
  }

  @override
  Future<void> complete(String token) async {
    final p = _waiting.remove(token);
    if (p == null) return;
    await _sdk.complete(p, consumable: catalog[p.productId] == ProductKind.consumable);
  }

  void _onSdk(List<SdkPurchase> batch) {
    for (final p in batch) {
      switch (p.status) {
        case SdkPurchaseStatus.pending:
          _out.add(PurchasePending(p.productId));
        case SdkPurchaseStatus.canceled:
          _out.add(PurchaseFailed(p.productId, 'cancelled'));
        case SdkPurchaseStatus.error:
          _out.add(PurchaseFailed(p.productId, p.error == 'alreadyOwned' ? 'alreadyOwned' : 'error'));
        case SdkPurchaseStatus.purchased || SdkPurchaseStatus.restored:
          if (!_valid(p)) {
            _out.add(PurchaseFailed(p.productId, 'invalid'));
            continue;
          }
          final restored = p.status == SdkPurchaseStatus.restored;
          if (restored) _restoring?.add(p.productId);
          if (p.needsComplete) _waiting[p.token] = p;
          _out.add(PurchaseDelivered(p.productId, token: p.token, at: p.at ?? DateTime.now(), restored: restored));
      }
    }
  }

  bool _valid(SdkPurchase p) =>
      catalog.containsKey(p.productId) &&
      p.token.isNotEmpty &&
      (_package == null || p.packageName == null || p.packageName == _package);

  Future<void> dispose() async {
    await _sub.cancel();
    await _out.close();
  }
}

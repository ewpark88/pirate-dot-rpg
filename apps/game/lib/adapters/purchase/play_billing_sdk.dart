import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:pirate_dot/adapters/purchase/billing_sdk.dart';

/// 실제 Play 결제(in_app_purchase 3.3.1). 판단은 PlayPurchases(시험됨) — 여기는 SDK 모양만 바꾼다.
/// 소모형은 autoConsume을 끄고 산다: 앱이 지급·저장을 끝낸 뒤 [complete]에서 consume(그 전에 죽으면 Play가 다시 보낸다).
class PlayBillingSdk implements BillingSdk {
  PlayBillingSdk([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final Map<String, ProductDetails> _details = {};

  /// complete를 기다리는 SDK 구매(토큰별) — SdkPurchase에는 SDK 객체를 싣지 않는다.
  final Map<String, PurchaseDetails> _raw = {};

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<SdkProduct>> query(Set<String> ids) async {
    final res = await _iap.queryProductDetails(ids);
    return [
      for (final p in res.productDetails)
        SdkProduct(
          id: (_details[p.id] = p).id,
          price: p.price,
          currency: p.currencyCode,
          micros: (p.rawPrice * Duration.microsecondsPerSecond).round(),
        ),
    ];
  }

  @override
  Future<bool> buy(String productId, {required bool consumable}) async {
    try {
      final pd = _details[productId] ?? (await _iap.queryProductDetails({productId})).productDetails.firstOrNull;
      if (pd == null) return false;
      final param = PurchaseParam(productDetails: pd);
      return consumable
          ? await _iap.buyConsumable(purchaseParam: param, autoConsume: false)
          : await _iap.buyNonConsumable(purchaseParam: param);
    } on Object {
      return false; // 결제 창을 못 띄움(이미 진행 중 등) — PlayPurchases가 'error'로 알린다
    }
  }

  @override
  Stream<List<SdkPurchase>> get purchases => _iap.purchaseStream.map((list) => [for (final d in list) _toSdk(d)]);

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<void> complete(SdkPurchase purchase, {required bool consumable}) async {
    final d = _raw.remove(purchase.token);
    if (d == null) return;
    if (consumable && Platform.isAndroid) {
      // consume = 확인(acknowledge)까지 포함 — 다시 살 수 있게 된다.
      await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().consumePurchase(d);
      return;
    }
    if (d.pendingCompletePurchase) await _iap.completePurchase(d);
  }

  SdkPurchase _toSdk(PurchaseDetails d) {
    final token = d.verificationData.serverVerificationData;
    if (token.isNotEmpty) _raw[token] = d;
    final ms = int.tryParse(d.transactionDate ?? '');
    return SdkPurchase(
      productId: d.productID,
      status: switch (d.status) {
        PurchaseStatus.pending => SdkPurchaseStatus.pending,
        PurchaseStatus.purchased => SdkPurchaseStatus.purchased,
        PurchaseStatus.restored => SdkPurchaseStatus.restored,
        PurchaseStatus.canceled => SdkPurchaseStatus.canceled,
        PurchaseStatus.error => SdkPurchaseStatus.error,
      },
      token: token,
      packageName: d is GooglePlayPurchaseDetails ? d.billingClientPurchase.packageName : null,
      at: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      needsComplete: d.pendingCompletePurchase,
      error: (d.error?.message ?? '').contains('itemAlreadyOwned') ? 'alreadyOwned' : d.error?.code,
    );
  }
}

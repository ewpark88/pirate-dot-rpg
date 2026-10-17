/// Play 결제 라이브러리(in_app_purchase)를 감싼 얇은 경계. 실제 구현은 SDK 의존성이 들어온 뒤 `play_billing_sdk.dart`, 시험은 가짜.
/// 판단(검증·순서·복원 차이)은 여기 두지 않는다 — 전부 PlayPurchases에서 시험한다.
enum SdkPurchaseStatus { pending, purchased, restored, error, canceled }

/// 스토어 상품 한 개(SDK ProductDetails).
class SdkProduct {
  const SdkProduct({required this.id, required this.price, this.currency, this.micros});

  final String id;
  final String price;
  final String? currency;
  final int? micros;
}

/// 구매 소식 한 개(SDK PurchaseDetails). [token] = Android purchaseToken(서버 검증 데이터).
class SdkPurchase {
  const SdkPurchase({
    required this.productId,
    required this.status,
    this.token = '',
    this.packageName,
    this.at,
    this.needsComplete = false,
    this.error,
  });

  final String productId;
  final SdkPurchaseStatus status;
  final String token;

  /// 영수증의 패키지 이름(Android originalJson packageName). 모르면 null(검증 건너뜀).
  final String? packageName;
  final DateTime? at;

  /// SDK pendingCompletePurchase — 완료(acknowledge/consume)가 필요한가.
  final bool needsComplete;
  final String? error;
}

abstract interface class BillingSdk {
  Future<bool> isAvailable();

  /// 모르는 id는 결과에서 빠진다.
  Future<List<SdkProduct>> query(Set<String> ids);

  /// 결제 창을 띄운다(결과는 [purchases]). 창을 못 띄우면 false. [consumable]이면 소모형(다시 살 수 있음).
  Future<bool> buy(String productId, {required bool consumable});

  /// SDK purchaseStream — 앱이 켜져 있는 동안 하나.
  Stream<List<SdkPurchase>> get purchases;

  /// 소유분을 [purchases]로 다시 보낸다(restored). 끝나면 돌아온다.
  Future<void> restore();

  /// completePurchase(Android: 비소모 acknowledge, 소모 consume).
  Future<void> complete(SdkPurchase purchase, {required bool consumable});
}

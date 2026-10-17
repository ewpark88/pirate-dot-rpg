// 결제 포트 모양(계약 요청서 docs/contracts/requests/platform-iap.md — S1 방향 승인 2026-10-18). 계약(game_core PurchasePort v2)이
// 머지되기 전까지 앱 안 임시 정의 — 머지되면 이 파일을 지우고 game_core 것을 쓴다(이름·모양 그대로).

enum ProductKind { consumable, nonConsumable, subscription }

/// 스토어가 준 상품 정보(현지화 가격 글). 없으면 그 상품 버튼을 숨긴다.
class ProductInfo {
  const ProductInfo({required this.id, required this.kind, required this.price, this.currency, this.micros});

  final String id;
  final ProductKind kind;
  final String price;
  final String? currency;
  final int? micros;
}

/// 구매 흐름에서 오는 소식. 지급은 [PurchaseDelivered]에서만 한다.
sealed class PurchaseUpdate {
  const PurchaseUpdate(this.productId);

  final String productId;
}

/// 결제 대기(편의점·보류 결제) — UI '처리 중'. 아직 지급하지 않는다.
class PurchasePending extends PurchaseUpdate {
  const PurchasePending(super.productId);
}

/// 지급해도 됨(로컬 검증 통과). 지급·저장 뒤 [PurchaseService.complete]([token]).
class PurchaseDelivered extends PurchaseUpdate {
  const PurchaseDelivered(super.productId, {required this.token, required this.at, this.restored = false});

  final String token;
  final DateTime at;

  /// 복원으로 다시 온 소유분(비소모·구독) — 새 보상 연출 없이 권리만 켠다.
  final bool restored;
}

/// 실패: cancelled · error · unavailable · alreadyOwned · invalid.
class PurchaseFailed extends PurchaseUpdate {
  const PurchaseFailed(super.productId, this.reason);

  final String reason;
}

/// 복원 조회에서 사라짐(구독 만료·환불) — 권리를 끈다.
class PurchaseRevoked extends PurchaseUpdate {
  const PurchaseRevoked(super.productId);
}

/// 결제 포트(계약 요청서 1절과 같은 모양).
abstract interface class PurchaseService {
  /// 결제 가능한 기기·계정인가(아니면 상점을 숨긴다).
  Future<bool> available();

  Future<List<ProductInfo>> products(Set<String> ids);

  /// 결과는 [updates]로.
  Future<void> buy(String productId);

  Stream<PurchaseUpdate> get updates;

  /// 소유한 비소모·구독을 다시 받는다. [active] 가운데 스토어에 없는 것은 [PurchaseRevoked].
  Future<void> restore({required Set<String> active});

  /// 지급·저장이 끝난 뒤에만 부른다(acknowledge/consume — 3일 안에 안 하면 Play가 자동 환불).
  Future<void> complete(String token);
}

/// 결제 없음(iOS M6 전·SDK 실패·운영자 끔): 상점을 숨긴다.
class NoPurchases implements PurchaseService {
  const NoPurchases();

  @override
  Future<bool> available() async => false;

  @override
  Future<List<ProductInfo>> products(Set<String> ids) async => const [];

  @override
  Future<void> buy(String productId) async {}

  @override
  Stream<PurchaseUpdate> get updates => const Stream.empty();

  @override
  Future<void> restore({required Set<String> active}) async {}

  @override
  Future<void> complete(String token) async {}
}
